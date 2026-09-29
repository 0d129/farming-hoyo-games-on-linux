# Copy to config.sh and edit. Shared by setup.sh and bettergi.sh.

# Steam app ID of the GenshinImpact.exe non-Steam shortcut (its prefix is compatdata/<ID>).
# With the game running:  xprop WM_CLASS  (click the game window) -> "steam_app_<ID>"
GI_APPID=1234567890

# Where the game and BetterGI live. Use a Linux file system (ext4, btrfs), not NTFS.
GAMES_DIR="$HOME/Games"
GI_DIR="$GAMES_DIR/Genshin Impact game"
BGI_DIR="$GAMES_DIR/BetterGI"

# Optional: a folder that already holds both "Genshin Impact game" and "BetterGI"
# (for example a Windows drive), for `setup.sh copy`. Leave empty to skip copying.
SRC_DIR=""

STEAM_ROOT="$HOME/.steam/steam"
# Must be the same Proton the game uses, or BetterGI gets its own wineserver and can't see the game.
PROTON_DIR="$STEAM_ROOT/steamapps/common/Proton 9.0 (Beta)"
