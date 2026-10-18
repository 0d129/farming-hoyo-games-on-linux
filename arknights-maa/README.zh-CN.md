# 明日方舟（国服 PC 端）+ MAA

[English](README.md) | 简体中文

用 GE-Proton 运行明日方舟官方 PC 端（国服，鹰角启动器），把 [MAA](https://github.com/MaaAssistantArknights/MaaAssistantArknights) 放在同一个 Proton 前缀里，通过 MAA 的「PC 端」（Win32）连接方式控制游戏。[farm-chain](../farm-chain/README.zh-CN.md) 可以在米哈游游戏之后无人值守地运行它。

| 文件 | 作用 |
|---|---|
| `config.example.sh` | 复制为 `config.sh`：安装目录、GE-Proton 版本，可选 Discord webhook 和 MAA-Meow 导出文件。 |
| `setup.sh` | 安装和配置除下载游戏以外的所有东西；每一步都可以单独运行、重复运行。 |
| `maa.sh` | `./maa.sh` 打开 MAA；`run` 无人值守（启动游戏、跑任务队列、退出）；`stop` 关闭 MAA（游戏不受影响）；`kill` 停掉整个前缀。 |
| `maa_config.py` | 修改 MAA 的 `config/gui.new.json`：下文的各项设置、farm-chain 用的自动运行开关、MAA-Meow 导入。 |
| `steam_add_shortcut.py` | 给启动器添加 Steam 非 Steam 游戏快捷方式，强制使用 GE-Proton，并写入下文的启动选项。 |

## 用哪个 MAA？

MAA 的 Linux 发行包（`MAA-*-linux-x86_64`）是 maa-cli 加 MaaCore，只带 ADB 控制器，官方也没有 Linux 图形界面。它能控制安卓模拟器或 Waydroid，但**控制不了 PC 端**。PC 端只能用 Win32 控制器，而它只在 Windows 版里有。所以这里用 Wine 运行 Windows 图形界面版（`MAA.exe`），并让它和游戏共用同一个前缀和 wineserver。图形界面版还有 maa-cli 没有的功能，比如启动客户端、任务完成后的动作、外部通知。

## 安装

```bash
cd farming-hoyo-games-on-linux/arknights-maa
cp config.example.sh config.sh && nano config.sh
./setup.sh            # 执行 shortcut 这一步时 Steam 必须关闭
```
然后下载游戏：从 Steam 启动 **明日方舟** 快捷方式（会打开启动器），登录，点 **下载游戏**，安装目录保持默认（约 30 GB）。之后：
```bash
./maa.sh              # 打开一次 MAA，让它生成配置文件，然后关掉
./setup.sh maaconfig  # PC 端连接等设置（同时写入 Discord webhook）
./setup.sh meow       # 可选：从 MAA-Meow 导出文件复制任务设置
```
游戏里 **设置 → 游戏 → UI 缩放** 保持 100%，分辨率保持 16:9（MAA 要求）。

## 日常使用

- 自己玩：从 Steam 启动 **明日方舟**，会打开启动器，再点「开始游戏」。
- 手动跑 MAA：开始菜单里的 **MAA（明日方舟）**，或者运行 `maa.sh`。游戏没开的话 MAA 会自己启动它。任务运行时 MAA 会移动真实的鼠标（见下文）。要停止：开始菜单里的 **停止 MAA（明日方舟）**、`maa.sh stop`，或者 MAA 的热键 Ctrl+Shift+Alt+L。
- 无人值守：在 `../farm-chain/config.sh` 里设置 `ARKNIGHTS=1`。MAA 自带的定时已经关闭，由 farm-chain 的 cron 运行 `maa.sh run`。这个命令只在当次运行时打开 MAA 的「启动后直接运行」和「完成后退出明日方舟 + 退出 MAA」。

## 遇到的问题和解决办法

| 问题 | 原因 | 解决办法（在哪里） |
|---|---|---|
| 启动器安装程序以退出码 2 结束，什么都没装（`/S`） | NSIS 安装程序拒绝静默安装 | 用 7z 解包；顶层的 `Launcher.exe` 是个引导程序，它运行 `<版本号>/Games.exe`（`setup.sh launcher`） |
| 点「开始游戏」没反应：`Arknights.exe` 约 1 秒后退出，退出码 `0xDEADC0DE` | 游戏的保护模块（`ArknightsBase.dll`）在 Wine 11 以下（Proton 9）会主动结束进程 | 启动器、游戏和 MAA 都用 GE-Proton 11（带 syscall user dispatch 的 Wine 11）（`setup.sh proton`、`config.sh`） |
| 游戏在主界面卡住，画面发白（KDE 的“无响应”效果） | 游戏会打开一个内置网页（`PlatformProcess`，QtWebEngine），用 GPU 渲染时这个窗口一直不出现，游戏就一直等它 | `QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu ..." QT_OPENGL=software`（`maa.sh`、Steam 启动选项） |
| MAA 窗口黑屏、不刷新 | Wine 下 WPF 的硬件渲染 | `HKCU\Software\Microsoft\Avalon.Graphics\DisableHWAcceleration=1`（`setup.sh registry`） |
| MAA 窗口点不动 | Wine 把鼠标锁在全屏游戏里；MAA 自己的弹出通知在被关掉之前也会占住焦点 | Wine 的 `X11 Driver\GrabPointer=N`、`GrabFullscreen=N`（`setup.sh registry`）；关闭 MAA 的系统通知（`maaconfig`） |
| MAA 能识别开始界面，但点击没反应 | Wine 下 Unity 不响应 `PostMessage*` 系列鼠标输入方式发出的窗口消息 | 鼠标输入方式用 **Seize**（`maaconfig`） |
| MAA 的截图是全黑的，或者截到了任务栏、其他窗口 | 游戏用 DXVK 渲染，`PrintWindow` 只能截到黑屏；`ScreenDC` 截的是屏幕上对应的区域，所以游戏必须是窗口模式并且在最前面 | 截图方式用 **ScreenDC**，游戏以 1280x720 窗口模式启动（`maaconfig`），`maa.sh run` 运行时把游戏窗口保持在最前面 |
| Discord 通知 | MAA 的 Discord 选项是 Bot（Token + User ID） | 用自定义 Webhook，套 MAA 自带的「Discord Webhook」模板，消息体 `{"content": "{content}"}`（`maaconfig`） |

## 局限

- **Seize 会移动真实的鼠标，ScreenDC 截的是屏幕画面。** MAA 跑任务时电脑没法用，游戏必须保持窗口模式并在最前面（`maa.sh run` 每 15 秒把它切到前台）。最好在你不用电脑时运行（farm-chain 夜间运行），用 `maa.sh stop` 或开始菜单里的快捷方式停止。
- 游戏带有 ACE（AntiCheatExpert）反作弊，鹰角也不支持 Linux。GE-Proton 是正常的兼容层，不是绕过反作弊的工具，但不能保证没有风险。
- MAA 用 DPAPI 加密保存 webhook 地址，`maaconfig` 写入的是明文。MAA 会提示一次，等那个设置页下次保存时再加密。
- `setup.sh meow` 不会导入 MAA-Meow 的「库存保持」计划，请在 MAA 自己的「库存保持」任务里设置。MAA-Meow 只适用于安卓的设置在这里没有对应项。

## 许可证

GPL-3.0，见 [LICENSE](../LICENSE)。
