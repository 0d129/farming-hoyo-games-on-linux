#!/bin/bash
# Run MAA (Windows build) in the Arknights Proton prefix, so it can find and control the PC client.
#
#   ./maa.sh          open MAA; it starts the game itself if the game isn't running
#   ./maa.sh run      unattended (farm-chain): MAA starts the game, runs its task queue, then exits
#   ./maa.sh stop     close MAA (gives the mouse back while Seize input is running); the game stays
#   ./maa.sh kill     stop everything in the prefix: game, launcher and MAA
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$HERE/config.sh" ] || { echo "copy config.example.sh to config.sh and edit it first" >&2; exit 1; }
. "$HERE/config.sh"

export STEAM_COMPAT_DATA_PATH="$ARK_PREFIX" STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
# The game opens an in-game web page (PlatformProcess, QtWebEngine) on its home screen. With GPU
# rendering that window never appears and the game waits for it forever; software rendering works.
# The game inherits this from MAA, which starts it.
export QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu --disable-gpu-compositing --no-sandbox" QT_OPENGL=software
CFG="$MAA_DIR/config/gui.new.json"
MAA_RE='^[A-Z]:.*\\MAA[.]exe( |$)'   # Wine's argv[0], not a shell line that mentions MAA.exe
GAME_TITLE="明日方舟"

maa_running() { pgrep -f "$MAA_RE" >/dev/null; }
for f in "$PROTON_DIR/proton" "$MAA_DIR/MAA.exe"; do
  [ -e "$f" ] || { echo "not found: $f (run setup.sh)" >&2; exit 1; }
done

case "${1:-gui}" in
  gui)
    maa_running && { echo "MAA is already running"; exit 1; }
    cd "$MAA_DIR" && exec "$PROTON_DIR/proton" run "$MAA_DIR/MAA.exe"
    ;;
  run)
    maa_running && { echo "MAA is already running"; exit 1; }
    [ -f "$CFG" ] || { echo "no $CFG: open MAA once (./maa.sh) and run setup.sh maaconfig" >&2; exit 1; }
    python3 "$HERE/maa_config.py" "$CFG" autorun on >/dev/null || exit 1
    # MAA saves its config when it exits, so switch auto-run back off after that, also when killed
    trap 'python3 "$HERE/maa_config.py" "$CFG" autorun off >/dev/null' EXIT
    trap 'kill "$pid" 2>/dev/null; exit 143' TERM INT
    cd "$MAA_DIR" || exit 1
    "$PROTON_DIR/proton" run "$MAA_DIR/MAA.exe" &
    pid=$!
    # MAA takes screenshots of, and clicks on, whatever is on screen where the game is: keep the
    # game window in front (Wine windows started outside Steam all have WM_CLASS steam_proton,
    # so match the title)
    while kill -0 "$pid" 2>/dev/null; do
      python3 "$HERE/../zzz-onedragon/raise_game.py" "name=$GAME_TITLE" >/dev/null 2>&1
      sleep 15
    done &
    wait "$pid"
    ;;
  stop)
    pkill -f "$MAA_RE"; sleep 3; pkill -9 -f "$MAA_RE" 2>/dev/null
    echo "MAA stopped"
    ;;
  kill)
    WINEPREFIX="$ARK_PREFIX/pfx" "$PROTON_DIR/files/bin/wineserver" -k
    ;;
  *)
    sed -n '2,8p' "$0"; exit 2
    ;;
esac
