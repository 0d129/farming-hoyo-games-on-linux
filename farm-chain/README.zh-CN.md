# 无人值守串联：定时跑原神 + 绝区零

[English](README.md) | 简体中文

按顺序无人值守地运行 [genshin-bettergi](../genshin-bettergi/README.zh-CN.md) 和 [zzz-onedragon](../zzz-onedragon/README.zh-CN.md)（例如用 cron 定时），作用类似 Windows 上的 OneDragon-ScriptChainer。请先把这两部分各自配置好并测试通过。

| 文件 | 作用 |
|---|---|
| `config.example.sh` | 复制为 `config.sh`，填两个游戏的 Steam app ID，可选填 Discord webhook。 |
| `farm-chain.sh` | 运行串联。`./farm-chain.sh` 跑全部步骤；`./farm-chain.sh zzz` 只跑指定的步骤（`genshin`、`zzz`）。 |
| `farm-chain-cron.sh` | 给 cron 用的入口：从桌面会话借用 `DISPLAY`/`XAUTHORITY`/D-Bus，再运行 `farm-chain.sh`。 |
| `kwin-rule.sh` | 仅 KDE：添加一条窗口规则，防止 BetterGI 的遮罩窗口被最大化（见[下文](#bettergi-报-cannot-show-window-when-showactivated-is-false-and-windowstate-is-set-to-maximized)）。 |

## 每一步做什么

1. 从 Steam 启动游戏（`steam://rungameid/...`），最多尝试 6 次。开机后第一次启动米哈游游戏经常在 30 秒内闪退。
2. 启动工具：`bettergi.sh startOneDragon` 或 `zzz-od.sh run -c`。
3. 每 10 秒检查一次游戏和工具是否还在运行。游戏窗口失去焦点时把它切回前台：BetterGI 在游戏处于后台时会暂停，而 KDE 会阻止 Wine 自己抢回焦点。
4. 游戏关闭（两个工具都设置成跑完后关闭游戏）、工具退出或者超时（`GI_TIMEOUT` 40 分钟，`ZZZ_TIMEOUT` 20 分钟）时结束这一步，然后停掉游戏的整个 wineserver。

以下情况**会把这一步重跑一次**：
- 工具启动后 120 秒内游戏就关闭了（启动后闪退）；
- 工具启动后卡死：5 分钟内没有在自己的日志里写出“已就绪”标志（BetterGI 是 `启用一条龙配置`，一条龙是 `指令[ 进入游戏 ]`）。两个工具都出现过加载完 OCR 模型后就无声卡住的情况；
- BetterGI 陷入已知的报错循环（见下文）。如果不检测，它们会一直空等到超时。

在 `config.sh` 里设置 `DISCORD_WEBHOOK` 后，每次运行结束都会把汇总（每一步每次尝试的结果）发到 Discord。这样即使工具卡死、没发出自己的通知，也能收到失败消息。

日志在 `~/.cache/farm-chain/chain-<日期>.log`，工具自己的输出在 `~/.cache/farm-chain/<步骤>-tool.log`。

每次游戏启动失败，都会在 `~/.cache/farm-chain/diag/<时间>-<游戏>-<第几次>/` 留下诊断信息（保留最近 20 次）：
- 截图：窗口出现时、游戏加载中、游戏退出后各一张；
- 窗口列表和 Wine 进程列表；
- 这次启动期间游戏和 Wine 写出的文件（游戏日志、`driverError.log`、崩溃转储）；
- Steam 对这个游戏的进程日志。

## 安装

```bash
cd farming-hoyo-games-on-linux/farm-chain
cp config.example.sh config.sh
nano config.sh          # GI_APPID、ZZZ_APPID、DISCORD_WEBHOOK（可选）
./farm-chain.sh         # 先手动跑一次
./kwin-rule.sh          # 仅 KDE，推荐
crontab -e
```
例如每天 01:00 和 06:00 运行：
```
0 1,6 * * * /path/to/farming-hoyo-games-on-linux/farm-chain/farm-chain-cron.sh
```
运行时必须已经登录桌面（锁屏可以），机器也不能休眠。找不到桌面会话时，`farm-chain-cron.sh` 会把这一情况写进日志然后退出。

## 常见问题

### BetterGI 报 `Cannot show Window when ShowActivated is false and WindowState is set to Maximized`
所有任务都会在 `TaskRunner.Init` 立刻失败，BetterGI 为每个任务发一条 `task.error` 通知，日志里这个异常每秒刷约 25 次。原因是在 Wine 下，BetterGI 的遮罩窗口（`MaskWindow`，一个和游戏一样大的无边框窗口）偶尔会被设成最大化状态，之后 WPF 就拒绝再显示它。这种情况很少见（我这里大约 20 次运行出现一次）。

- `farm-chain.sh` 会在 `~/.cache/bettergi-wine.log` 里检测这条消息，一旦出现就停掉这一步并重跑。
- `kwin-rule.sh` 强制这个窗口永不最大化。在 Proton 的 wine 下，它的 WM_CLASS 是 `steam_proton`，标题是 `MaskWindow`，可以用 `xprop` 确认。

## 许可证

GPL-3.0，见 [LICENSE](../LICENSE)。
