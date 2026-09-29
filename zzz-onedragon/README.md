# ZenlessZoneZero-OneDragon on Linux

English | [简体中文](README.zh-CN.md)

Run [ZenlessZoneZero-OneDragon](https://github.com/OneDragon-Anything/ZenlessZoneZero-OneDragon) (绝区零一条龙) on Linux, with Zenless Zone Zero running under Steam + Proton.

OneDragon is a Windows program. Here it runs **headless** (no GUI) with its own embedded Windows Python, inside the **same Proton prefix and wineserver as the game**. That way it can see the game window, capture screenshots and send input like it does on Windows.

The OneDragon source is not modified. Everything is in a few small scripts:

| File | What it does |
|---|---|
| `zzz-od.sh` | Launcher. Sets up the Wine environment, raises the game window, starts OneDragon. |
| `bootstrap.py` | Loads OneDragon from its folder, forces the BitBlt screenshot method, sends clicks to `xinput_server.py`, adds the `test`, `enter` and `app` modes and a fix for going back to the world. |
| `xinput_server.py` | Performs OneDragon's mouse clicks from the X11 side (the game ignores clicks sent from inside Wine in the open world). Started and stopped by `zzz-od.sh`. |
| `raise_game.py` | Brings the game window to the front from the X11 side (Wine's own call is blocked by KDE). |
| `config.example.sh` | Copy to `config.sh` and set your paths. |

## Tested on

- Ubuntu with kernel 7.0, KDE Plasma on **X11**, AMD Radeon 680M
- Steam, **Proton 9.0 (Beta)**, game in a 1280×720 window (OneDragon scales it to its 1080p layout)
- OneDragon at commit `8b52af8` (embedded Python 3.11.12)
- A full one-dragon run passed: login from the title screen, café, video store, scratch card, Drive Disc dismantling, Ridu City fund, activity rewards, stamina farming in the Simulation Room (with combat), notification.

Wayland sessions are untested. `raise_game.py` talks to the X server, so it may only work for XWayland windows, or not at all.

## Setup

### 1. Game: add ZenlessZoneZero.exe to Steam

Get a Windows copy of the game folder: from an existing Windows install, or by running HoYoPlay under Proton.

**Keep the game on a Linux file system (ext4, btrfs), not NTFS.** See the [NTFS warning](../README.md#warnings).

In Steam: **Games → Add a Non-Steam Game** → pick `ZenlessZoneZero.exe`. Then open **Properties → Compatibility**, force **Proton 9.0 (Beta)**, and start the game once so Steam creates its prefix.

Find the shortcut's app ID. With the game running, run `xprop WM_CLASS` and click the game window. You'll see `steam_app_<ID>`. The prefix is `~/.steam/steam/steamapps/compatdata/<ID>/pfx`.

### 2. OneDragon: get a full installed folder

You need an OneDragon folder that has already been installed, i.e. it contains `.install/python/...` and `.venv/`.

The tested way is to **install and configure OneDragon on Windows**, then copy the whole folder to Linux (for example `~/Games/ZZZ_OD`). Configuration (accounts, instances, what to farm) lives in `config/` and comes along with the copy. The absolute path recorded in `.venv` doesn't matter; `bootstrap.py` loads the packages directly.

Untested alternative: run `OneDragon-Installer.exe` inside the game's prefix with Proton.

### 3. Add a native `ucrtbase.dll`

Proton's built-in `ucrtbase.dll` is missing `crealf`, which numpy needs, so OneDragon fails at import. Put Microsoft's 64-bit `ucrtbase.dll` **next to `python.exe`**:

```
<OneDragon>/.install/python/cpython-3.11.12-windows-x86_64-none/ucrtbase.dll
```

Copy it from a Windows 10/11 machine's `C:\Windows\System32\ucrtbase.dll` (tested: version 10.0.19041.685). It isn't included here because it's Microsoft's file. The launcher sets `WINEDLLOVERRIDES=ucrtbase=n,b`, so only processes that find this copy use it; the game keeps Proton's.

### 4. Get the scripts

```bash
git clone https://github.com/0d129/farming-hoyo-games-on-linux.git
cd farming-hoyo-games-on-linux/zzz-onedragon
cp config.example.sh config.sh
nano config.sh          # set ZZZ_APPID and OD_DIR
```

If your Proton isn't `Proton 9.0 (Beta)` in the default Steam library, set `PROTON_DIR` too. It must be **the same Proton the game uses**, otherwise OneDragon starts its own wineserver and can't see the game.

## Usage

1. Start ZZZ from Steam. The title screen is enough; `run` logs in by itself.
   Right after a reboot the first launch sometimes dies within ~30 seconds (empty window frame). Just start it again.
2. Run the self-test:
   ```bash
   ./zzz-od.sh test
   ```
   It raises the game, takes one screenshot, runs OCR, and prints `PASS` or `FAIL`. The screenshot is saved to `<OneDragon>/.debug/linux_selftest.png`. Open it and check it shows the game.
3. Run the one-dragon routine:
   ```bash
   ./zzz-od.sh run -i 1       # instance 1; use -i 1,2 for several
   ./zzz-od.sh run -i 1 -c    # close the game when done
   ```
   `run` first gets the game from the title screen into the world (`./zzz-od.sh enter` does only that step), then starts one-dragon.
4. To run a single application instead, pass its app ID, for example stamina farming:
   ```bash
   ./zzz-od.sh app charge_plan
   ```

While it runs, **don't touch the mouse or keyboard or switch windows**. As on Windows, input goes to whatever is in front. Logs are in `<OneDragon>/.log/`.

To make it a command: `ln -s "$PWD/zzz-od.sh" ~/.local/bin/zzz-od`.

## How it works / why each piece exists

- **Same prefix, same wineserver.** OneDragon finds the game with Win32 window APIs, which only see windows of the same wineserver. So `WINEPREFIX` points at the game's prefix, and `WINEFSYNC`/`WINEESYNC` match Proton's so Wine connects to the running wineserver instead of refusing or starting a new one.
- **BitBlt screenshots.** `bootstrap.py` forces the `bitblt` method (override with `ZZZ_OD_SCREENSHOT=...`) without editing `env.yml`, so the same folder still works on Windows. BitBlt copies what is *on screen* in the game's area, so the game must be uncovered.
- **Raising the window.** OneDragon calls `SetForegroundWindow`, but KDE's focus-stealing prevention ignores it from Wine. `raise_game.py` sends an EWMH `_NET_ACTIVE_WINDOW` request as a pager, which KDE honours. The self-test fails if the game still isn't in front, so a covered game can't give a false `PASS`.
- **Clicks go through X11.** In the open world ZZZ locks the cursor, and under Wine it ignores mouse clicks sent from inside Wine (so buttons like the top-left menu never open). A real X11 click with ALT held works. `zzz-od.sh` starts `xinput_server.py` on a local port, and `bootstrap.py` replaces OneDragon's click function so each click is sent there and done with XTest: hold ALT, move the mouse, click. Combat keys and attacks are sent another way and are not affected. Set `ZZZ_OD_XINPUT_ALT=0` to click without ALT.
- **Entering the game.** OneDragon only logs in by itself when it launched the game, but here Steam launches it. So `run` first runs OneDragon's own enter-game step (title screen → login → world), or skips it if the game is already in the world.
- **Back to the world, then check again.** OneDragon returns to the world by clicking the top-left Back arrow, the same spot as the world's menu button. A click that lands just after the screen changed opens the menu, and the next step then clicks into the menu by mistake (seen as a Dennies info popup). `bootstrap.py` makes that step wait 1.5 s and check once more before continuing.
- **`ucrtbase` override.** See step 3.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `game window (steam_app_…) not found` | Game not running, or `ZZZ_APPID` is wrong. Check with `xprop WM_CLASS`. |
| `FAIL: game window not found` (after OCR loads) | OneDragon is on a different wineserver. `PROTON_DIR` must be the game's Proton; don't change `WINEFSYNC`/`WINEESYNC`. |
| numpy import error mentioning `crealf` | Native `ucrtbase.dll` missing next to `python.exe` (step 3). |
| Screenshot shows your terminal, not the game | Something covered the game. The current self-test catches this; keep the game in front. |
| In the open world, the cursor flashes every few seconds and nothing happens; log shows `打开邮件 返回状态 按钮-菜单` over and over | Clicks are not reaching the game. Make sure `xinput_server.py` is next to `zzz-od.sh` and starts (it needs `libXtst`, an X11 session). |
| `enter game: success=False status=未知画面` | The game was on a screen OneDragon doesn't know at start. Bring it to the title screen or the world and run again. |
| First launch after boot dies after ~30 s, or shows an empty window frame | Happens with HoYo games right after boot. Start it again; the second launch works. |
| `RuntimeError: unsupported format` from `soundcard` during combat | Harmless. Wine can't record game audio, so OneDragon turns off sound-based dodging and keeps its visual dodge. |
| Game stuck on a black screen at start, `Player.log` shows `IOException: Win32 IO returned 998` | Game files are damaged or unwritable (see Warnings). Move the game to a Linux file system. |

The game's Unity log is at `<prefix>/drive_c/users/steamuser/AppData/LocalLow/miHoYo/ZenlessZoneZero/Player.log`.

## Warnings

Read the [shared warnings](../README.md#warnings) first, especially: **don't run the game from an NTFS drive mounted with `ntfs3`**.

## License

GPL-3.0 (see [LICENSE](../LICENSE)), same as OneDragon.
