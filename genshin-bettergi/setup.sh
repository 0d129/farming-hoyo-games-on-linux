#!/bin/bash
# Set up Genshin Impact (Steam + Proton) and BetterGI on Linux, following
# https://www.bettergi.com/tutorial/run_on_linux.html plus the extra fixes Proton needs.
# Every step is safe to re-run.
#
#   ./setup.sh            all steps below, in order
#   ./setup.sh <step>...  only those steps
#
# Steps:
#   copy      rsync Genshin + BetterGI from $SRC_DIR to $GAMES_DIR (skipped if SRC_DIR is unset)
#   shortcut  point the Steam shortcut $GI_APPID at $GI_DIR/GenshinImpact.exe (Steam must be closed)
#   dotnet    install the .NET 8 Desktop Runtime into the game's prefix
#   fonts     make sure Chinese fonts (Microsoft YaHei, SimSun) are in the prefix
#   registry  add HKCU\Software\Classes and point the bettergi:// handler at $BGI_DIR
#   bgiconfig BetterGI: captureMode=BitBlt, installPath=$GI_DIR (Wine has no DwmGetDxSharedSurface)
#   launcher  link bettergi.sh into ~/.local/bin
set -e
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$HERE/config.sh" ] || { echo "copy config.example.sh to config.sh and edit it first" >&2; exit 1; }
. "$HERE/config.sh"

PFX="$STEAM_ROOT/steamapps/compatdata/$GI_APPID/pfx"
WINE="$PROTON_DIR/files/bin/wine"
DOTNET_URL="https://aka.ms/dotnet/8.0/windowsdesktop-runtime-win-x64.exe"

say() { printf '\n== %s\n' "$*"; }
wine_q() { "$WINE" "$@" </dev/null 2>&1 | grep -v writewatch || true; }
winpath() { echo "Z:$(echo "$1" | tr / '\\')"; }
steam_running() { pgrep -x steam >/dev/null || pgrep -f 'ubuntu12_32/steam( |$)' >/dev/null; }
wine_env() {
  export WINEPREFIX="$PFX" WINEFSYNC=1 WINEESYNC=1 WINEDEBUG=-all
  [ -x "$WINE" ] || { echo "Proton not found: $WINE" >&2; exit 1; }
  [ -d "$PFX" ] || { echo "prefix $PFX missing: start the Genshin shortcut from Steam once (Proton 9.0 forced)" >&2; exit 1; }
}

step_copy() {
  say "copy: $SRC_DIR -> $GAMES_DIR"
  if [ -z "$SRC_DIR" ]; then echo "SRC_DIR not set, skipping"; return; fi
  if [ ! -d "$SRC_DIR" ]; then echo "$SRC_DIR not found (drive not mounted?), skipping"; return; fi
  mkdir -p "$GAMES_DIR"
  # Read-only on the source. Only copy to ext4: writing to NTFS via ntfs3 has corrupted game files before.
  (cd "$SRC_DIR" && rsync -a --info=progress2 --no-inc-recursive \
    "$(basename "$GI_DIR")" "$(basename "$BGI_DIR")" "$GAMES_DIR/")
}

step_shortcut() {
  say "shortcut: Steam app $GI_APPID -> $GI_DIR/GenshinImpact.exe"
  if steam_running; then echo "Steam is running. Quit it (Steam > Exit) and re-run: ./setup.sh shortcut" >&2; return 1; fi
  local f
  for f in "$STEAM_ROOT"/userdata/*/config/shortcuts.vdf; do
    [ -f "$f" ] && python3 "$HERE/steam_shortcut.py" "$f" "$GI_APPID" "$GI_DIR/GenshinImpact.exe"
  done
}

step_dotnet() {
  say "dotnet: .NET 8 Desktop Runtime in $PFX"
  wine_env
  if ls -d "$PFX/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App/8."* >/dev/null 2>&1; then
    echo "already installed: $(ls "$PFX/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App")"; return
  fi
  local exe="$HOME/.cache/bettergi-setup/windowsdesktop-runtime-8-win-x64.exe"
  mkdir -p "$(dirname "$exe")"
  [ -s "$exe" ] || curl -fL -o "$exe" "$DOTNET_URL"
  wine_q "$exe" /install /quiet /norestart
  "$PROTON_DIR/files/bin/wineserver" -w
  ls "$PFX/drive_c/Program Files/dotnet/shared/Microsoft.WindowsDesktop.App"
}

step_fonts() {
  say "fonts: Chinese fonts in $PFX/drive_c/windows/Fonts"
  local fonts="$PFX/drive_c/windows/Fonts" f
  mkdir -p "$fonts"
  # Proton ships Microsoft YaHei and SimSun; link them if the prefix lacks them.
  for f in msyh.ttf simsun.ttc; do
    if [ -e "$fonts/$f" ]; then echo "ok: $f"
    elif [ -e "$PROTON_DIR/files/share/fonts/$f" ]; then ln -s "$PROTON_DIR/files/share/fonts/$f" "$fonts/$f"; echo "linked: $f"
    else echo "missing: $f (copy a Chinese font into $fonts)" >&2
    fi
  done
  # Optional extra fonts, as in the tutorial: FONT_DIR=/path/to/fonts ./setup.sh fonts
  if [ -n "$FONT_DIR" ]; then cp -v "$FONT_DIR"/*.tt[fc] "$FONT_DIR"/*.otf "$fonts/" 2>/dev/null || true; fi
}

step_registry() {
  say "registry: HKCU\\Software\\Classes and bettergi:// handler"
  wine_env
  # BetterGI crashes registering its URL protocol if HKCU\Software\Classes doesn't exist.
  wine_q reg add 'HKCU\Software\Classes' /f
  wine_q reg add 'HKCU\Software\Classes\BetterGI' /ve /d BetterGI /f
  wine_q reg add 'HKCU\Software\Classes\BetterGI' /v 'URL Protocol' /d '' /f
  wine_q reg add 'HKCU\Software\Classes\BetterGI\shell\open\command' /ve \
    /d "\"$(winpath "$BGI_DIR/BetterGI.exe")\" \"%1\"" /f
  "$PROTON_DIR/files/bin/wineserver" -w
  grep -A3 -F '[Software\\Classes\\BetterGI\\shell\\open\\command]' "$PFX/user.reg" | grep '^@='
}

step_bgiconfig() {
  say "bgiconfig: $BGI_DIR/User/config.json"
  local cfg="$BGI_DIR/User/config.json"
  if [ ! -f "$cfg" ]; then echo "no config yet (start BetterGI once, then re-run: ./setup.sh bgiconfig)"; return; fi
  # Match Wine's Windows-path argv[0], not any command line that merely mentions BetterGI.exe
  if pgrep -f '^[A-Z]:.*BetterGI[.]exe' >/dev/null; then echo "BetterGI is running and would overwrite the change; close it and re-run" >&2; return 1; fi
  python3 - "$cfg" "$(winpath "$GI_DIR/GenshinImpact.exe")" <<'PY'
import json, re, shutil, sys, time
path, gi = sys.argv[1], sys.argv[2]
s = open(path, encoding='utf-8-sig').read()
new = re.sub(r'("captureMode":\s*)"[^"]*"', r'\1"BitBlt"', s)
new = re.sub(r'("installPath":\s*)"[^"]*"', lambda m: m.group(1) + json.dumps(gi), new, count=1)
json.loads(new)  # still valid JSON
if new == s:
    print('already up to date')
else:
    shutil.copy2(path, f'{path}.bak-{time.strftime("%Y%m%d-%H%M%S")}')
    open(path, 'w', encoding='utf-8').write(new)
for k in ('captureMode', 'installPath'):
    print(re.search(rf'"{k}":\s*"[^"]*"', new).group(0))
PY
}

step_launcher() {
  say "launcher: ~/.local/bin/bettergi.sh -> $HERE/bettergi.sh"
  local dst="$HOME/.local/bin/bettergi.sh"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && [ ! -L "$dst" ]; then mv "$dst" "$dst.bak-$(date +%Y%m%d-%H%M%S)"; fi
  ln -sfn "$HERE/bettergi.sh" "$dst"
  ls -l "$dst"
}

ALL=(copy shortcut dotnet fonts registry bgiconfig launcher)
for s in "${@:-${ALL[@]}}"; do
  declare -F "step_$s" >/dev/null || { echo "unknown step: $s (steps: ${ALL[*]})" >&2; exit 2; }
  "step_$s"
done
say "done"
