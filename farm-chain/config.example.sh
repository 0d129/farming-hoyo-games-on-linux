# Copy to config.sh and edit.

# Steam app IDs of the GenshinImpact.exe and ZenlessZoneZero.exe non-Steam shortcuts
# (the same values as GI_APPID in ../genshin-bettergi/config.sh and ZZZ_APPID in ../zzz-onedragon/config.sh).
GI_APPID=1234567890
ZZZ_APPID=1234567890

# Optional: Discord webhook URL; each run's result is posted there (also when a tool hangs and
# never sends its own notification). Keep it out of git: config.sh is in .gitignore.
DISCORD_WEBHOOK=""

# Where BetterGI and OneDragon live (their logs tell whether a tool got past its startup).
# BGI_DIR="$HOME/Games/BetterGI"
# OD_DIR="$HOME/Games/ZZZ_OD"

# Optional overrides:
# STEAM_ROOT="$HOME/.steam/steam"
# PROTON_DIR="$STEAM_ROOT/steamapps/common/Proton 9.0 (Beta)"
# GI_TIMEOUT=2400    # seconds before a step is stopped
# ZZZ_TIMEOUT=1200
