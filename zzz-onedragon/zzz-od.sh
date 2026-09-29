#!/bin/bash
# Run ZenlessZoneZero-OneDragon headless inside the game's own Proton prefix.
# Start ZZZ from Steam first, then:
#   ./zzz-od.sh test          capture + OCR self-test (screenshot -> $OD_DIR/.debug/linux_selftest.png)
#   ./zzz-od.sh enter         get from the title screen into the game world
#   ./zzz-od.sh run [args]    enter the game, then one-dragon run; args: -i 1,2 (instances)  -c (close game after)
#   ./zzz-od.sh app <app_id>  run one application, e.g. app charge_plan
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$HERE/config.sh" ] && . "$HERE/config.sh"

: "${ZZZ_APPID:?set ZZZ_APPID in config.sh (see README)}"
: "${OD_DIR:?set OD_DIR in config.sh (see README)}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.steam/steam}"
PROTON_DIR="${PROTON_DIR:-$STEAM_ROOT/steamapps/common/Proton 9.0 (Beta)}"
PY_DIR="${PY_DIR:-$OD_DIR/.install/python/cpython-3.11.12-windows-x86_64-none}"

export WINEPREFIX="$STEAM_ROOT/steamapps/compatdata/$ZZZ_APPID/pfx"
export WINEFSYNC=1 WINEESYNC=1   # match Proton's sync mode so it can share the game's wineserver
export WINEDLLOVERRIDES="ucrtbase=n,b"   # Proton's ucrtbase lacks crealf (numpy); native copy sits next to python.exe
export WINEDEBUG=-all PYTHONIOENCODING=utf-8 PYTHONUNBUFFERED=1

winpath() { echo "Z:$(echo "$1" | tr / '\\')"; }
export ZZZ_OD_WINDIR="$(winpath "$OD_DIR")"

for f in "$PROTON_DIR/files/bin/wine" "$PY_DIR/python.exe" "$WINEPREFIX"; do
  [ -e "$f" ] || { echo "not found: $f" >&2; exit 1; }
done
[ -f "$PY_DIR/ucrtbase.dll" ] || echo "warning: $PY_DIR/ucrtbase.dll missing, numpy will fail to load (see README)" >&2

cd "$OD_DIR" || exit 1
# Wine's own SetForegroundWindow is blocked by KDE focus-stealing prevention; raise from the X11 side.
python3 "$HERE/raise_game.py" "steam_app_$ZZZ_APPID" || exit 1
sleep 1
# X11-side click helper (see xinput_server.py); stopped when this script exits
export ZZZ_OD_XINPUT_PORT="${ZZZ_OD_XINPUT_PORT:-47391}"
python3 "$HERE/xinput_server.py" "$ZZZ_OD_XINPUT_PORT" &
XINPUT_PID=$!
trap 'kill $XINPUT_PID 2>/dev/null' EXIT
sleep 0.5
od() {
  "$PROTON_DIR/files/bin/wine" "$(winpath "$PY_DIR/python.exe")" "$(winpath "$HERE/bootstrap.py")" "$@" </dev/null 2>&1 \
    | grep --line-buffered -v -E 'use_kernel_writewatch|^Fontconfig error'
  return "${PIPESTATUS[0]}"
}
mode="${1:-run}"
if [ "$mode" = run ]; then
  od enter || { echo "could not enter the game, not starting one-dragon" >&2; exit 1; }
fi
od "$mode" "${@:2}"
