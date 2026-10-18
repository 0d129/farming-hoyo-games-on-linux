#!/bin/bash
# Set up Arknights (CN PC client) and MAA on Linux: the Hypergryph launcher and the game run under
# GE-Proton, MAA's Windows GUI runs in the same prefix and drives the game through its Win32 (PC) mode.
# Every step is safe to re-run.
#
#   ./setup.sh            all steps below except meow, in order
#   ./setup.sh <step>...  only those steps
#
# Steps:
#   proton    download $GE_PROTON_RELEASE into Steam's compatibilitytools.d
#   launcher  download the Hypergryph launcher and unpack it to $LAUNCHER_DIR (its silent install fails under Wine)
#   prefix    create the Proton prefix $ARK_PREFIX
#   registry  Wine: no pointer grab (else MAA's window can't be clicked), WPF software rendering (else MAA's window turns black)
#   maa       download MAA (Windows x64 build) to $MAA_DIR
#   maaconfig MAA: PC connection, MAA starts the game, own schedule and system notifications off,
#             Discord webhook (MAA must have been opened once, and be closed)
#   meow      only when named: copy task settings from a MAA-Meow export ($MAAMEOW_CONFIG); overwrites
#             task changes made in MAA since
#   shortcut  Steam shortcut "$SHORTCUT_NAME" for the launcher, with GE-Proton forced (Steam must be closed)
#   desktop   menu entries "MAA（明日方舟）" and "停止 MAA（明日方舟）", maa.sh in ~/.local/bin
#
# Not scripted: downloading the game itself (open the launcher once: ./setup.sh prints how).
set -e
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
[ -f "$HERE/config.sh" ] || { echo "copy config.example.sh to config.sh and edit it first" >&2; exit 1; }
. "$HERE/config.sh"

CACHE="$HOME/.cache/arknights-maa-setup"
CFG="$MAA_DIR/config/gui.new.json"
mkdir -p "$CACHE"

say() { printf '\n== %s\n' "$*"; }
steam_running() { pgrep -x steam >/dev/null || pgrep -f 'ubuntu12_32/steam( |$)' >/dev/null; }
proton_env() { export STEAM_COMPAT_DATA_PATH="$ARK_PREFIX" STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"; }
wine_reg() {
  WINEPREFIX="$ARK_PREFIX/pfx" WINEDEBUG=-all "$PROTON_DIR/files/bin/wine" reg add "$@" /f </dev/null 2>&1 |
    grep -v writewatch || true
}

step_proton() {
  say "proton: $PROTON_DIR"
  if [ -x "$PROTON_DIR/proton" ]; then echo "already installed"; return; fi
  local base="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$GE_PROTON_RELEASE"
  local tar="$GE_PROTON_RELEASE-x86_64.tar.gz"
  (cd "$CACHE" && curl -fLO "$base/$tar" && curl -fLO "$base/$GE_PROTON_RELEASE-x86_64.sha512sum" &&
    sha512sum -c "$GE_PROTON_RELEASE-x86_64.sha512sum")
  mkdir -p "$(dirname "$PROTON_DIR")"
  tar -xzf "$CACHE/$tar" -C "$(dirname "$PROTON_DIR")"
  [ -x "$PROTON_DIR/proton" ] || { echo "unpacked, but $PROTON_DIR/proton is missing: check PROTON_DIR" >&2; exit 1; }
}

step_launcher() {
  say "launcher: $LAUNCHER_DIR"
  if [ -f "$LAUNCHER_DIR/Launcher.exe" ]; then echo "already there (it updates itself)"; return; fi
  command -v 7z >/dev/null || { echo "7z not found (apt install p7zip-full)" >&2; exit 1; }
  local exe="$CACHE/HypergryphLauncher_setup.exe" x="$CACHE/launcher-unpacked" ver
  curl -fL -o "$exe" "$LAUNCHER_URL"
  rm -rf "$x"; 7z x -y -o"$x" "$exe" >/dev/null
  # The NSIS installer puts a <version>/ folder under the install dir; Launcher.exe at the top is a
  # small stub that starts <version>/Games.exe. The payload only has the copy inside <version>/.
  ver=$(basename "$(dirname "$(find "$x/\$0" -mindepth 2 -maxdepth 2 -name Games.exe | head -1)")")
  mkdir -p "$LAUNCHER_DIR"
  cp -a "$x/\$0/." "$LAUNCHER_DIR/"
  cp "$LAUNCHER_DIR/$ver/Launcher.exe" "$LAUNCHER_DIR/Launcher.exe"
  rm -rf "$x"
  echo "launcher $ver unpacked"
}

step_prefix() {
  say "prefix: $ARK_PREFIX"
  if [ -f "$ARK_PREFIX/pfx/system.reg" ]; then echo "already there"; return; fi
  mkdir -p "$ARK_PREFIX"; proton_env
  "$PROTON_DIR/proton" run wineboot -u </dev/null >/dev/null 2>&1
  "$PROTON_DIR/files/bin/wineserver" -w
  ls "$ARK_PREFIX/pfx"
}

step_registry() {
  say "registry: $ARK_PREFIX/pfx"
  # With pointer grabs, Wine confines the mouse to the fullscreen game and no other window
  # (MAA included) gets clicks.
  wine_reg 'HKCU\Software\Wine\X11 Driver' /v GrabPointer /t REG_SZ /d N
  wine_reg 'HKCU\Software\Wine\X11 Driver' /v GrabFullscreen /t REG_SZ /d N
  # MAA's WPF window turns black and stops redrawing with hardware rendering
  wine_reg 'HKCU\Software\Microsoft\Avalon.Graphics' /v DisableHWAcceleration /t REG_DWORD /d 1
  WINEPREFIX="$ARK_PREFIX/pfx" "$PROTON_DIR/files/bin/wineserver" -w
}

step_maa() {
  say "maa: $MAA_DIR"
  if [ -f "$MAA_DIR/MAA.exe" ]; then echo "already there (MAA updates itself)"; return; fi
  command -v unzip >/dev/null || { echo "unzip not found" >&2; exit 1; }
  local api="https://api.github.com/repos/MaaAssistantArknights/MaaAssistantArknights/releases" url
  [ "$MAA_VERSION" = latest ] && api+="/latest" || api+="/tags/$MAA_VERSION"
  url=$(curl -fsSL "$api" | python3 -c 'import json, sys
print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith("-win-x64.zip")))')
  curl -fL -o "$CACHE/maa-win-x64.zip" "$url"
  mkdir -p "$MAA_DIR"; unzip -q -o "$CACHE/maa-win-x64.zip" -d "$MAA_DIR"
  ls "$MAA_DIR/MAA.exe"
}

maa_closed() {
  [ -f "$CFG" ] || { echo "no MAA config yet: open MAA once (./maa.sh), close it, then re-run: ./setup.sh $1"; return 1; }
  if pgrep -f '^[A-Z]:.*\\MAA[.]exe( |$)' >/dev/null; then
    echo "MAA is running and would overwrite the change; close it (./maa.sh stop) and re-run: ./setup.sh $1" >&2; return 1
  fi
}

step_maaconfig() {
  say "maaconfig: $CFG"
  maa_closed maaconfig || return 0
  python3 "$HERE/maa_config.py" "$CFG" setup "$GAME_EXE" "$DISCORD_WEBHOOK"
}

step_meow() {
  say "meow: $MAAMEOW_CONFIG -> MAA tasks"
  [ -n "$MAAMEOW_CONFIG" ] || { echo "MAAMEOW_CONFIG not set, skipping"; return; }
  maa_closed meow || return 0
  python3 "$HERE/maa_config.py" "$CFG" meow "$MAAMEOW_CONFIG"
}

step_shortcut() {
  say "shortcut: Steam \"$SHORTCUT_NAME\" -> $LAUNCHER_DIR/Launcher.exe"
  if steam_running; then echo "Steam is running. Quit it (Steam > Exit) and re-run: ./setup.sh shortcut" >&2; return 1; fi
  local f opts
  opts="QTWEBENGINE_CHROMIUM_FLAGS=\"--disable-gpu --disable-gpu-compositing --no-sandbox\" QT_OPENGL=software"
  opts+=" STEAM_COMPAT_DATA_PATH=$ARK_PREFIX %command%"
  for f in "$STEAM_ROOT"/userdata/*/config/shortcuts.vdf; do
    [ -f "$f" ] && python3 "$HERE/steam_add_shortcut.py" "$f" "$STEAM_ROOT/config/config.vdf" \
      "$SHORTCUT_NAME" "$LAUNCHER_DIR/Launcher.exe" "$opts" "$(basename "$PROTON_DIR")"
  done
}

step_desktop() {
  say "desktop: menu entries, ~/.local/bin/maa.sh"
  local apps="$HOME/.local/share/applications"
  mkdir -p "$apps" "$HOME/.local/bin"
  ln -sfn "$HERE/maa.sh" "$HOME/.local/bin/maa.sh"
  cat >"$apps/maa-arknights.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MAA（明日方舟）
Comment=MAA in the Arknights Proton prefix
Exec=$HERE/maa.sh
Icon=applications-games
Terminal=false
Categories=Game;
EOF
  cat >"$apps/maa-arknights-stop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=停止 MAA（明日方舟）
Comment=Close MAA (gives the mouse back); the game keeps running
Exec=$HERE/maa.sh stop
Icon=process-stop
Terminal=false
Categories=Game;
EOF
  update-desktop-database "$apps" 2>/dev/null || true
  ls -l "$HOME/.local/bin/maa.sh"
}

ALL=(proton launcher prefix registry maa maaconfig shortcut desktop)
for s in "${@:-${ALL[@]}}"; do
  declare -F "step_$s" >/dev/null || { echo "unknown step: $s (steps: ${ALL[*]} meow)" >&2; exit 2; }
  "step_$s"
done
if [ ! -f "$GAME_EXE" ]; then
  say "next: download the game"
  echo "Start \"$SHORTCUT_NAME\" from Steam (or: STEAM_COMPAT_DATA_PATH=$ARK_PREFIX STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_ROOT \"$PROTON_DIR/proton\" run \"$LAUNCHER_DIR/Launcher.exe\"),"
  echo "click 下载游戏 and keep the default folder ($(dirname "$GAME_EXE")). Then open MAA once (./maa.sh), close it, and run: ./setup.sh maaconfig (and meow, to copy MAA-Meow tasks)"
fi
say "done"
