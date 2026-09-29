# Genshin Impact + BetterGI on Linux

English | [简体中文](README.zh-CN.md)

Run [BetterGI](https://github.com/babalae/better-genshin-impact) (更好的原神) on Linux, with Genshin Impact running under Steam + Proton.

BetterGI runs with its normal GUI **inside the same Proton prefix and wineserver as the game**, so it can find the game window, capture it and send input. This follows the official [Linux tutorial](https://www.bettergi.com/tutorial/run_on_linux.html), plus a few extra fixes Proton needs, all automated by `setup.sh`.

| File | What it does |
|---|---|
| `config.example.sh` | Copy to `config.sh` and set the app ID and paths. |
| `setup.sh` | Every setup step. Each one is safe to re-run. `./setup.sh` runs all of them; `./setup.sh <step>` runs one. |
| `bettergi.sh` | Launcher. Start Genshin from Steam first, then run this. |
| `steam_shortcut.py` | Changes the game path of a Steam non-Steam shortcut, keeping its app ID (and so its Proton prefix). |

## Tested on

- Ubuntu with kernel 7.0, KDE Plasma on X11, AMD Radeon 680M
- Steam, **Proton 9.0 (Beta)**
- .NET 8 Desktop Runtime 8.0.31 in the game's prefix
- BetterGI ran daily commissions end to end: teleporting, pathing, combat and pickups.

## Setup

1. **Get the files.** You need a Windows copy of the Genshin game folder and a BetterGI folder, for example from a Windows install. **Keep them on a Linux file system (ext4, btrfs), not NTFS.** See the [NTFS warning](../README.md#warnings). If they're currently on another drive, `setup.sh copy` can copy them for you (set `SRC_DIR`).
2. **Add the game to Steam.** In Steam: **Games → Add a Non-Steam Game** → pick `GenshinImpact.exe`. Open **Properties → Compatibility** and force **Proton 9.0 (Beta)**. Start the game once so Steam creates its prefix, then quit it.
3. **Configure:**
   ```bash
   git clone https://github.com/0d129/farming-hoyo-games-on-linux.git
   cd farming-hoyo-games-on-linux/genshin-bettergi
   cp config.example.sh config.sh
   nano config.sh
   ```
   Set `GI_APPID`: with the game running, run `xprop WM_CLASS` and click the game window, and it shows `steam_app_<ID>`. Also set `GI_DIR`/`BGI_DIR` if your folders are elsewhere.
4. **Quit Steam** (Steam → Exit), then run:
   ```bash
   ./setup.sh
   ```
   The `bgiconfig` step needs BetterGI's `User/config.json`, which BetterGI creates the first time it runs. On a fresh BetterGI, start it once with `bettergi.sh`, close it, then run `./setup.sh bgiconfig`.

### What each step does

| Step | What / why |
|---|---|
| `copy` | Optional. `rsync` the game and BetterGI from `SRC_DIR` into `GAMES_DIR`. Skipped if `SRC_DIR` is empty. |
| `shortcut` | Points the Steam shortcut `GI_APPID` at `GI_DIR/GenshinImpact.exe`. Only needed if you moved the game after adding it to Steam. **Steam must be closed**, or it overwrites the change. A backup is saved as `shortcuts.vdf.bak-*`. |
| `dotnet` | Installs the .NET 8 Desktop Runtime into the game's prefix (tutorial step 4). |
| `fonts` | Makes sure Chinese fonts (Microsoft YaHei, SimSun) are in the prefix (tutorial step 3). Proton already ships them, so they're linked. For extra fonts: `FONT_DIR=/path ./setup.sh fonts`. |
| `registry` | Creates `HKCU\Software\Classes`. Without it, BetterGI crashes while registering its `bettergi://` URL handler. Also points that handler at `BGI_DIR`. |
| `bgiconfig` | Sets BetterGI's capture mode to `BitBlt`, because Wine lacks `DwmGetDxSharedSurface`, which the default mode needs. Also sets the game path to `GI_DIR`. A backup is saved as `config.json.bak-*`. |
| `launcher` | Links `bettergi.sh` into `~/.local/bin`, so you can run `bettergi.sh` from anywhere. |

## Usage

1. Start Genshin from Steam.
2. Run `bettergi.sh`. BetterGI's window opens; use it as on Windows.
3. Start the capture and your tasks in BetterGI, then click the game window. BetterGI pauses whenever the game isn't the focused window (its log says so), so leave the game in front and don't use the mouse or keyboard while it runs.

Logs:
- Wine / launcher output: `~/.cache/bettergi-wine.log`
- BetterGI's own log: `BGI_DIR/log/`

## How it works / why each piece exists

- **Same prefix, same wineserver.** BetterGI finds the game with Win32 window APIs, which only see windows in the same wineserver. So `bettergi.sh` uses the game's prefix, and sets `WINEFSYNC=1 WINEESYNC=1` to match Proton so Wine joins the running wineserver. `PROTON_DIR` must be the same Proton the game uses.
- **`DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`**, as the official tutorial says.
- **No terminal attached.** BetterGI crashes in `ConsoleHelper` ("Invalid function") when its standard input/output is a Linux terminal, so the launcher redirects them to the log file.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `not found: …` from `bettergi.sh` | A path in `config.sh` is wrong, or setup hasn't run. |
| `prefix … missing` | Start the game from Steam once, with Proton 9.0 (Beta) forced, so the prefix exists. |
| BetterGI crashes right after starting, mentioning the registry or URL protocol | Run `./setup.sh registry`. |
| BetterGI can't capture the game, or the capture is black | Run `./setup.sh bgiconfig` with BetterGI closed. Capture mode must be `BitBlt`. |
| BetterGI can't find the game window | BetterGI is on a different wineserver. Check `PROTON_DIR`, and don't change `WINEFSYNC`/`WINEESYNC`. |
| The game dies ~30 s after launch with no window (Proton log: crash in `MHYPBase.dll`) | Happens right after a reboot. Launch it again a few seconds later; the second launch works. |
| `Fontconfig error: … out of memory` in the log | Harmless. |

## License

GPL-3.0 (see [LICENSE](../LICENSE)). BetterGI itself is not included.
