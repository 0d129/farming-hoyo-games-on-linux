#!/bin/bash
# Cron entry point for farm-chain.sh: cron has no desktop session env, so borrow
# DISPLAY/XAUTHORITY/D-Bus from a running process of this user, then run the chain.
for p in $(pgrep -u "$(id -u)"); do
  env_file=$(tr '\0' '\n' 2>/dev/null <"/proc/$p/environ") || continue
  grep -q '^DISPLAY=' <<<"$env_file" && grep -q '^XAUTHORITY=' <<<"$env_file" || continue
  eval "$(grep -E '^(DISPLAY|XAUTHORITY|DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)=' <<<"$env_file" | sed 's/^/export /; s/=\(.*\)$/="\1"/')"
  break
done
if [ -z "$DISPLAY" ]; then
  mkdir -p "$HOME/.cache/farm-chain"
  echo "[$(date '+%F %T')] cron: no X session found (not logged in?)" >>"$HOME/.cache/farm-chain/chain-$(date +%Y%m%d).log"
  exit 1
fi
export PATH="$HOME/.local/bin:/usr/games:/usr/local/bin:/usr/bin:/bin"
exec "$(dirname "$(readlink -f "$0")")/farm-chain.sh" "$@"
