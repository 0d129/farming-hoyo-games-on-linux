#!/bin/bash
# Launch BetterGI inside the Genshin Impact Proton prefix.
# Start Genshin from Steam first, then run this script.
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$HERE/config.sh" ] || { echo "copy config.example.sh to config.sh and edit it first" >&2; exit 1; }
. "$HERE/config.sh"

export WINEPREFIX="$STEAM_ROOT/steamapps/compatdata/$GI_APPID/pfx"
export WINE="$PROTON_DIR/files/bin/wine"
export WINEFSYNC=1 WINEESYNC=1   # match Proton's sync mode so it can share the game's wineserver
export DOTNET_SYSTEM_GLOBALIZATION_USENLS=1
export WINEDEBUG=-all
for f in "$WINE" "$WINEPREFIX" "$BGI_DIR/BetterGI.exe"; do
  [ -e "$f" ] || { echo "not found: $f (run setup.sh)" >&2; exit 1; }
done
LOG="$HOME/.cache/bettergi-wine.log"
mkdir -p "$(dirname "$LOG")"
cd "$BGI_DIR" || exit 1
# BetterGI crashes in ConsoleHelper if its std handles are a Linux terminal,
# so detach from the tty and send output to a log file instead.
echo "BetterGI starting; output -> $LOG"
exec "$WINE" BetterGI.exe "$@" </dev/null >"$LOG" 2>&1
