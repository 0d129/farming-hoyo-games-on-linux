# Unattended chain: Genshin + ZZZ on a schedule

English | [简体中文](README.zh-CN.md)

Runs [genshin-bettergi](../genshin-bettergi/README.md) and [zzz-onedragon](../zzz-onedragon/README.md) one after the other, unattended (for example from cron), like OneDragon-ScriptChainer does on Windows. Set up and test both of those first.

| File | What it does |
|---|---|
| `config.example.sh` | Copy to `config.sh` and set both games' Steam app IDs, and optionally a Discord webhook. |
| `farm-chain.sh` | Runs the chain. `./farm-chain.sh` runs all steps; `./farm-chain.sh zzz` runs only the named ones (`genshin`, `zzz`). |
| `farm-chain-cron.sh` | Entry point for cron: borrows `DISPLAY`/`XAUTHORITY`/D-Bus from your desktop session, then runs `farm-chain.sh`. |
| `kwin-rule.sh` | KDE only: adds a window rule that keeps BetterGI's overlay from being maximized (see [below](#bettergi-cannot-show-window-when-showactivated-is-false-and-windowstate-is-set-to-maximized)). |

## What each step does

1. Starts the game from Steam (`steam://rungameid/...`), retrying up to 3 times. Right after boot, the first launch of a HoYo game often dies within ~30 s.
2. Starts the tool: `bettergi.sh startOneDragon` or `zzz-od.sh run -c`.
3. Every 10 s: checks that the game and the tool are still running, and raises the game window if it lost focus (BetterGI pauses when the game is in the background, and KDE stops Wine from taking focus back).
4. Ends when the game closes (both tools are set to close it when done), the tool exits, or the timeout is reached (`GI_TIMEOUT` 40 min, `ZZZ_TIMEOUT` 20 min). Then it stops the game's whole wineserver.

A step is **run again once** when:
- the game closes within 120 s of the tool starting (a launch crash);
- the tool hangs at startup: it hasn't written its "ready" line to its own log within 5 min (BetterGI: `启用一条龙配置`, OneDragon: `指令[ 进入游戏 ]`). Both tools have been seen freezing silently right after loading their OCR models; or
- BetterGI hits a known error loop (see below). Without these checks it would idle until the timeout.

With `DISCORD_WEBHOOK` set in `config.sh`, a summary of each run (every attempt of every step and how it ended) is posted to Discord. This means a run where a tool hung and never sent its own notification still gets reported.

Log: `~/.cache/farm-chain/chain-<date>.log`. The tools' own output goes to `~/.cache/farm-chain/<step>-tool.log`.

## Setup

```bash
cd farming-hoyo-games-on-linux/farm-chain
cp config.example.sh config.sh
nano config.sh          # GI_APPID, ZZZ_APPID, DISCORD_WEBHOOK (optional)
./farm-chain.sh         # try it once by hand
./kwin-rule.sh          # KDE only, recommended
crontab -e
```
For example, to run at 01:00 and 06:00:
```
0 1,6 * * * /path/to/farming-hoyo-games-on-linux/farm-chain/farm-chain-cron.sh
```
You must be logged in to the desktop (a locked screen is fine), and the machine must not suspend. If no desktop session is found, `farm-chain-cron.sh` writes that to the log and exits.

## Troubleshooting

### BetterGI: `Cannot show Window when ShowActivated is false and WindowState is set to Maximized`
Every task fails immediately at `TaskRunner.Init`, BetterGI sends a `task.error` notification for each one, and its log fills with this exception (about 25 a second). Under Wine, BetterGI's overlay window (`MaskWindow`, a borderless window the size of the game) occasionally ends up in the maximized state, and WPF then refuses to show it again. It is rare (once in about 20 runs here).

- `farm-chain.sh` watches `~/.cache/bettergi-wine.log` for this message, and when it appears stops the step and runs it again.
- `kwin-rule.sh` forces that window to never be maximized. Under Proton's wine its WM_CLASS is `steam_proton` and its title is `MaskWindow`, which you can check with `xprop`.

## License

GPL-3.0, see [LICENSE](../LICENSE).
