# Arknights (CN PC client) + MAA

English | [简体中文](README.zh-CN.md)

Runs the official Arknights PC client (CN server, Hypergryph launcher) under GE-Proton, and [MAA](https://github.com/MaaAssistantArknights/MaaAssistantArknights) in the same Proton prefix, driving the game through MAA's PC (Win32) mode. [farm-chain](../farm-chain/README.md) can run it unattended after the HoYo games.

| File | What it does |
|---|---|
| `config.example.sh` | Copy to `config.sh`: install folders, GE-Proton release, optional Discord webhook and MAA-Meow export. |
| `setup.sh` | Installs and configures everything except the game download; each step can be run on its own and re-run. |
| `maa.sh` | `./maa.sh` opens MAA; `run` = unattended (start the game, run the task queue, exit); `stop` closes MAA (the game keeps running); `kill` stops the whole prefix. |
| `maa_config.py` | Edits MAA's `config/gui.new.json`: the settings below, auto-run on/off for farm-chain, MAA-Meow import. |
| `steam_add_shortcut.py` | Adds a Steam non-Steam shortcut for the launcher with GE-Proton forced and the launch options below. |

## Which MAA?

MAA's Linux release (`MAA-*-linux-x86_64`) is maa-cli plus MaaCore with only the ADB controller, and there is no official Linux GUI. It can drive an Android emulator or Waydroid, but **not the PC client**. The PC client can only be driven by the Win32 controller, which only exists in the Windows build. So this setup runs the Windows GUI (`MAA.exe`) with Wine, in the game's own prefix and wineserver. The GUI also has features maa-cli lacks, such as starting the client, post actions, and external notifications.

## Setup

```bash
cd farming-hoyo-games-on-linux/arknights-maa
cp config.example.sh config.sh && nano config.sh
./setup.sh            # Steam must be closed for the `shortcut` step
```
Then download the game: start the **明日方舟** shortcut from Steam (it opens the launcher), log in, click **下载游戏** and keep the default folder (about 30 GB). Then:
```bash
./maa.sh              # open MAA once so it writes its config, then close it
./setup.sh maaconfig  # PC connection etc. (also adds the Discord webhook)
./setup.sh meow       # optional: copy task settings from a MAA-Meow export
```
In the game, keep **设置 → 游戏 → UI 缩放** at 100% and a 16:9 resolution (MAA requires both).

## Everyday use

- Play: start **明日方舟** from Steam. That opens the launcher, then click 开始游戏.
- MAA by hand: menu entry **MAA（明日方舟）** or `maa.sh`. It starts the game if it isn't running. While tasks run, MAA moves the real mouse (see below). To stop it: menu entry **停止 MAA（明日方舟）**, `maa.sh stop`, or the MAA hotkey Ctrl+Shift+Alt+L.
- Unattended: set `ARKNIGHTS=1` in `../farm-chain/config.sh`. MAA's own schedule is switched off; farm-chain's cron runs `maa.sh run`, which turns on MAA's "run directly" and "exit Arknights + exit MAA when done" for that run only.

## What it took (problems found, and the fix used)

| Problem | Cause | Fix (where) |
|---|---|---|
| The launcher's installer exits with code 2 and installs nothing (`/S`) | the NSIS installer refuses silent mode | unpack it with 7z; `Launcher.exe` at the top is a stub that runs `<version>/Games.exe` (`setup.sh launcher`) |
| Clicking 开始游戏 does nothing: `Arknights.exe` dies after ~1 s, exit code `0xDEADC0DE` | the game's protection (`ArknightsBase.dll`) kills itself under Wine < 11 (Proton 9) | GE-Proton 11 (Wine 11 with syscall user dispatch) for the launcher, the game and MAA (`setup.sh proton`, `config.sh`) |
| The game freezes on the home screen, washed out (KDE's "not responding" look) | it opens an in-game web page (`PlatformProcess`, QtWebEngine) whose window never appears with GPU rendering, and waits for it | `QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu ..." QT_OPENGL=software` (`maa.sh`, Steam launch options) |
| MAA's window is black / doesn't redraw | WPF hardware rendering under Wine | `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1` (`setup.sh registry`) |
| MAA's window can't be clicked | Wine confines the pointer to the fullscreen game; MAA's own toast notifications also hold the focus until closed | Wine `X11 Driver\GrabPointer=N`, `GrabFullscreen=N` (`setup.sh registry`); MAA system notifications off (`maaconfig`) |
| MAA recognizes the title screen but its clicks do nothing | Unity ignores the posted window messages of the `PostMessage*` mouse methods under Wine | mouse input **Seize** (`maaconfig`) |
| MAA fails every task on the home screen | the `ScreenDC` screenshot method returns garbage once past the title screen | screenshots **PrintWindow** (`maaconfig`) |
| Discord notifications | MAA's Discord option is a bot (token + user ID) | Custom Webhook with MAA's "Discord Webhook" template, body `{"content": "{content}"}` (`maaconfig`) |

## Limitations

- **Seize moves the real mouse.** While MAA runs tasks the computer can't be used, and the game window has to stay in front. Run it when you are away (farm-chain at night), and stop it with `maa.sh stop` / the menu entry.
- The game ships ACE (AntiCheatExpert); Hypergryph doesn't support Linux. GE-Proton is a normal compatibility layer, not an anti-cheat bypass, but there is no guarantee.
- MAA keeps its webhook URL DPAPI-encrypted; `maaconfig` writes it in plain text. MAA warns once and encrypts it the next time that setting page is saved.
- `setup.sh meow` doesn't import MAA-Meow's 库存保持 (keep inventory) plans; set them in MAA's own 库存保持 task. MAA-Meow's Android-only settings have no counterpart.

## License

GPL-3.0, see [LICENSE](../LICENSE).
