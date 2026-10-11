#!/bin/bash
# Chain-run BetterGI (Genshin) and OneDragon (ZZZ), like OneDragon-ScriptChainer's 01.yml.
# For each step: start the game from Steam, start the tool, wait until the game or the tool
# closes (or the timeout), then kill both by stopping the game's wineserver. A step is retried
# once if the game dies right after the tool starts, the tool hangs at startup (READY) or it hits a
# known error loop (STUCK). With DISCORD_WEBHOOK set in config.sh, the result is posted to Discord.
#
#   ./farm-chain.sh           run all steps
#   ./farm-chain.sh zzz       run only the named steps (genshin, zzz)
# While a step runs the game is kept in the foreground; Ctrl+C stops the chain, the game and the tool.
# Log: ~/.cache/farm-chain/chain-<date>.log
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
REPO="$(dirname "$HERE")"
[ -f "$HERE/config.sh" ] || { echo "copy config.example.sh to config.sh and edit it first" >&2; exit 1; }
. "$HERE/config.sh"
: "${GI_APPID:?set GI_APPID in config.sh}" "${ZZZ_APPID:?set ZZZ_APPID in config.sh}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.steam/steam}"
PROTON_DIR="${PROTON_DIR:-$STEAM_ROOT/steamapps/common/Proton 9.0 (Beta)}"
BGI_DIR="${BGI_DIR:-$HOME/Games/BetterGI}"
OD_DIR="${OD_DIR:-$HOME/Games/ZZZ_OD}"
RAISE="$REPO/zzz-onedragon/raise_game.py"

# name | Steam shortcut app ID | game exe | tool command | tool exe (Wine argv[0]) | timeout (s)
STEPS=(
  "genshin|$GI_APPID|GenshinImpact.exe|$REPO/genshin-bettergi/bettergi.sh startOneDragon|BetterGI.exe|${GI_TIMEOUT:-2400}"
  "zzz|$ZZZ_APPID|ZenlessZoneZero.exe|$REPO/zzz-onedragon/zzz-od.sh run -c|python.exe|${ZZZ_TIMEOUT:-1200}"
)
GAME_START_TIMEOUT=300   # Steam may need to start first
GAME_START_TRIES=6       # launches before giving up; Genshin often dies within ~20s on the first 2-3
GAME_LOAD_WAIT=20        # let the game get past its splash before the tool looks at it
EARLY_EXIT=120           # game closing this soon after the tool started = launch crash, retry the step
STEP_TRIES=2             # attempts per step for retryable failures (early game exit, stuck/hung tool)
READY_TIMEOUT=300        # tool must log its READY line within this many seconds, or it is treated as hung

# Tool stuck in an error loop: "log file|grep -E pattern". The log is truncated when the tool starts.
# BetterGI under Wine sometimes gets its overlay window maximized; then every Show() throws, all
# one-dragon tasks fail at TaskRunner.Init and BetterGI idles until the timeout.
declare -A STUCK=(
  [genshin]="$HOME/.cache/bettergi-wine.log|ShowActivated is false and WindowState is set to Maximized"
)
# Tool got past its startup: "log file|grep -E pattern", only lines written after the tool started
# count. %DATE% becomes YYYYMMDD. Both tools have been seen hanging silently right after loading
# their OCR models (BetterGI before its one-dragon config, OneDragon before entering the game).
declare -A READY=(
  [genshin]="$BGI_DIR/log/better-genshin-impact%DATE%.log|启用一条龙配置"
  [zzz]="$OD_DIR/.log/log.txt|指令\[ 进入游戏 \]"
)

LOG_DIR="$HOME/.cache/farm-chain"; mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/chain-$(date +%Y%m%d).log"
exec > >(tee -a "$LOG") 2>&1
exec 9>"$LOG_DIR/chain.lock"   # children get 9>&- so Steam etc. do not keep the lock
flock -n 9 || { echo "farm-chain is already running"; exit 1; }

log() { echo "[$(date +%H:%M:%S)] $*"; }
notify() { notify-send -a farm-chain "farm-chain" "$*" 2>/dev/null || true; }
discord() {  # post to DISCORD_WEBHOOK (config.sh), if set
  [ -n "$DISCORD_WEBHOOK" ] || return 0
  python3 -c 'import json, sys; print(json.dumps({"content": sys.argv[1][:1900]}))' "$*" |
    curl -fsS -m 20 -H 'Content-Type: application/json' -d @- "$DISCORD_WEBHOOK" >/dev/null ||
    log "discord notification failed"
}
file_size() { stat -c %s "$1" 2>/dev/null || echo 0; }
# grep -E $3 in what was appended to $1 since it was $2 bytes long (whole file if it got rotated)
grep_since() {
  local from=$2; [ "$(file_size "$1")" -lt "$from" ] && from=0
  tail -c +$((from + 1)) "$1" 2>/dev/null | grep -qE "$3"
}
# Wine sets argv[0] to the program's Windows path, e.g. "Z:\home\...\GenshinImpact.exe"
wine_running() { pgrep -f "^[A-Z]:.*\\\\${1//./[.]}( |$)" >/dev/null; }
window_exists() {
  local w
  for w in $(xprop -root _NET_CLIENT_LIST 2>/dev/null | sed 's/.*# //; s/,//g'); do
    xprop -id "$w" WM_CLASS 2>/dev/null | grep -q "\"steam_app_$1\"" && return 0
  done
  return 1
}
game_is_active() {
  local w; w=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | sed 's/.*# //; s/,.*//')
  xprop -id "$w" WM_CLASS 2>/dev/null | grep -q "\"steam_app_$1\""
}
kill_prefix() {  # stops the game, the tool and anything else in that prefix
  WINEPREFIX="$STEAM_ROOT/steamapps/compatdata/$1/pfx" "$PROTON_DIR/files/bin/wineserver" -k 2>/dev/null
}

start_game() {  # appid game-exe; returns 0 once the game is running with a window
  # Right after boot the first launch of a HoYo game often dies within ~30s (Genshin: anti-cheat
  # crash, no window; ZZZ: empty window frame). A relaunch a few seconds later works, so retry at
  # once instead of waiting for the window timeout, and do not reset the prefix in between.
  local appid=$1 game=$2 try t seen
  if window_exists "$appid" && wine_running "$game"; then return 0; fi
  for ((try = 1; try <= GAME_START_TRIES; try++)); do
    log "launching $game from Steam (attempt $try)"
    steam "steam://rungameid/$(python3 -c "print(($appid << 32) | 0x02000000)")" >/dev/null 2>&1 9>&- &
    seen=0
    for ((t = 0; t < GAME_START_TIMEOUT; t += 2)); do
      sleep 2
      if wine_running "$game"; then
        seen=1
        if window_exists "$appid"; then
          sleep "$GAME_LOAD_WAIT"
          wine_running "$game" && return 0
          break
        fi
      elif [ "$seen" = 1 ]; then
        break   # the game process started and died
      fi
    done
    log "$game did not start properly (attempt $try, ${t}s)"
    # A dead game can leave its window frame behind; only then clear the prefix
    if window_exists "$appid"; then kill_prefix "$appid"; fi
    sleep 3
  done
  kill_prefix "$appid"
  return 1
}

run_step() {
  local name=$1 appid=$2 game=$3 cmd=$4 tool=$5 timeout=$6 t tool_pid result
  log "== $name: start"; notify "$name: starting"

  if ! start_game "$appid" "$game"; then
    log "$name: game failed to start, skipping"; notify "$name: game failed to start"
    STEP_RESULT="game failed to start"
    return 1
  fi
  python3 "$RAISE" "steam_app_$appid"

  local stuck_log= stuck_re=
  if [ -n "${STUCK[$name]}" ]; then
    IFS='|' read -r stuck_log stuck_re <<<"${STUCK[$name]}"
    : >"$stuck_log" 2>/dev/null   # drop the previous run's output so it cannot match
  fi

  local ready_log= ready_re= ready_from=0 ready=0
  if [ -n "${READY[$name]}" ]; then
    IFS='|' read -r ready_log ready_re <<<"${READY[$name]}"
    ready_log=${ready_log//%DATE%/$(date +%Y%m%d)}
    ready_from=$(file_size "$ready_log")
  else
    ready=1
  fi

  log "starting: $cmd"
  setsid $cmd </dev/null >>"$LOG_DIR/$name-tool.log" 2>&1 9>&- &
  tool_pid=$!
  CUR_APPID=$appid CUR_PID=$tool_pid

  result=timeout
  for ((t = 0; t < timeout; t += 10)); do
    sleep 10
    if ! wine_running "$game"; then result="game closed"; break; fi
    # the tool's own process (BetterGI.exe / python.exe) or its launcher script
    if ! wine_running "$tool" && ! kill -0 "$tool_pid" 2>/dev/null; then result="tool closed"; break; fi
    if [ -n "$stuck_log" ] && grep -qE "$stuck_re" "$stuck_log" 2>/dev/null; then result="tool stuck"; break; fi
    if [ "$ready" = 0 ]; then
      if grep_since "$ready_log" "$ready_from" "$ready_re"; then ready=1; log "$name: tool is running its tasks"
      elif [ "$t" -ge "$READY_TIMEOUT" ]; then result="tool hung at startup"; break; fi
    fi
    # BetterGI pauses when the game loses focus, and KDE blocks Wine from taking focus back
    game_is_active "$appid" || python3 "$RAISE" "steam_app_$appid" >/dev/null
  done
  log "$name: done ($result after ${t}s), killing game and tool"
  kill -- -"$tool_pid" 2>/dev/null
  kill_prefix "$appid"
  CUR_APPID= CUR_PID=
  sleep 5
  notify "$name: done ($result)"
  STEP_RESULT="$result after ${t}s"
  # 2 = worth another attempt: the game crashed right after launch, or the tool hung / hit a known error loop
  if [ "$result" = "tool stuck" ] || [ "$result" = "tool hung at startup" ] || { [ "$result" = "game closed" ] && [ "$t" -lt "$EARLY_EXIT" ]; }; then
    return 2
  fi
  [ "$result" != timeout ]
}

on_abort() {
  log "aborted, stopping current game and tool"
  [ -n "$CUR_PID" ] && kill -- -"$CUR_PID" 2>/dev/null
  [ -n "$CUR_APPID" ] && kill_prefix "$CUR_APPID"
  notify "chain aborted"; discord "farm-chain $START: aborted"; exit 130
}
trap on_abort INT TERM

want=("$@"); failed=0; summary=; START=$(date '+%m-%d %H:%M')
for s in "${STEPS[@]}"; do
  IFS='|' read -r name appid game cmd tool timeout <<<"$s"
  if [ ${#want[@]} -gt 0 ] && [[ ! " ${want[*]} " == *" $name "* ]]; then continue; fi
  for ((try = 1; ; try++)); do
    STEP_RESULT=
    run_step "$name" "$appid" "$game" "$cmd" "$tool" "$timeout"; rc=$?
    summary+=$'\n'"$([ "$rc" = 0 ] && echo "✅" || echo "❌") $name (attempt $try): $STEP_RESULT"
    [ "$rc" = 2 ] && [ "$try" -lt "$STEP_TRIES" ] || break
    log "$name: retrying the step (attempt $((try + 1)) of $STEP_TRIES)"
    sleep 10
  done
  [ "$rc" = 0 ] || failed=$((failed + 1))
  sleep 10
done
log "== chain finished, $failed step(s) failed or timed out"
notify "chain finished ($failed failed)"
discord "farm-chain $START: $([ "$failed" = 0 ] && echo "all steps OK" || echo "$failed step(s) failed or timed out")$summary"
