# Copy to config.sh and edit. Shared by setup.sh and maa.sh.

# Where the launcher, the game, the Proton prefix and MAA live. Use a Linux file system (ext4, btrfs).
ARK_DIR="$HOME/Games/Arknights"
LAUNCHER_DIR="$ARK_DIR/HypergryphLauncher"
GAME_EXE="$LAUNCHER_DIR/games/Arknights/Arknights.exe"   # where the launcher installs the game by default
ARK_PREFIX="$ARK_DIR/prefix-ge11"                         # STEAM_COMPAT_DATA_PATH; the Wine prefix is $ARK_PREFIX/pfx
MAA_DIR="$ARK_DIR/MAA"

STEAM_ROOT="$HOME/.steam/steam"
# The game needs Wine 11+ (GE-Proton 11): under Proton 9 it kills itself right after start.
# The game, the launcher and MAA must all use this same Proton, or MAA can't see the game.
GE_PROTON_RELEASE="GE-Proton11-9"
PROTON_DIR="$STEAM_ROOT/compatibilitytools.d/$GE_PROTON_RELEASE-x86_64"

# Hypergryph launcher download (CN server), from https://ak.hypergryph.com/news/0717
LAUNCHER_URL="https://launcher.hypergryph.com/launcher/get_latest_launcher?appcode=abYeZZ16BPluCFyT&ta=arknights&channel=1&sub_channel=1"

# MAA release to install ("latest" or a tag such as v6.19.0)
MAA_VERSION="latest"

# Name of the Steam non-Steam shortcut that `setup.sh shortcut` adds for the launcher
SHORTCUT_NAME="明日方舟"

# Optional: Discord webhook for MAA's own notifications (task done / error / stalled).
# Keep it out of git: config.sh is in .gitignore.
DISCORD_WEBHOOK=""

# Optional: a MAA-Meow (Android) config export to copy task settings from, for `setup.sh meow`
MAAMEOW_CONFIG=""
