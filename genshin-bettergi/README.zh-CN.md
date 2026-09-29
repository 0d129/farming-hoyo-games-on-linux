# 在 Linux 上运行原神 + BetterGI

[English](README.md) | 简体中文

在 Linux 上运行 [BetterGI（更好的原神）](https://github.com/babalae/better-genshin-impact)，原神通过 Steam + Proton 运行。

BetterGI 以正常的图形界面运行在**和游戏同一个 Proton 前缀、同一个 wineserver 里**，这样它能找到游戏窗口、截图和发送按键。做法基于官方的 [Linux 教程](https://www.bettergi.com/tutorial/run_on_linux.html)，再加上 Proton 需要的几处额外修正，全部由 `setup.sh` 自动完成。

| 文件 | 作用 |
|---|---|
| `config.example.sh` | 复制为 `config.sh`，填写 app ID 和路径。 |
| `setup.sh` | 全部安装步骤，每一步都可以重复运行。`./setup.sh` 运行全部；`./setup.sh <步骤>` 只运行某一步。 |
| `bettergi.sh` | 启动脚本。先从 Steam 启动原神，再运行它。 |
| `steam_shortcut.py` | 修改 Steam 非 Steam 游戏快捷方式的游戏路径，同时保留 app ID（也就保留了原来的 Proton 前缀）。 |

## 测试环境

- Ubuntu，内核 7.0，KDE Plasma（X11），AMD Radeon 680M
- Steam，**Proton 9.0 (Beta)**
- 游戏前缀中的 .NET 8 桌面运行时 8.0.31
- BetterGI 完整跑完了每日委托：传送、寻路、战斗和拾取都正常。

## 安装

1. **准备文件。** 需要一份 Windows 版原神游戏目录和一个 BetterGI 目录，例如从 Windows 安装中复制。**放在 Linux 文件系统（ext4、btrfs）上，不要放在 NTFS 盘上。** 原因见 [NTFS 注意事项](../README.zh-CN.md#注意事项)。如果它们现在在别的盘上，`setup.sh copy` 可以帮你复制（设置 `SRC_DIR`）。
2. **把游戏加入 Steam。** 在 Steam 中：**游戏 → 添加非 Steam 游戏** → 选择 `GenshinImpact.exe`。在 **属性 → 兼容性** 中强制使用 **Proton 9.0 (Beta)**。启动一次游戏让 Steam 创建前缀，然后退出游戏。
3. **填写配置：**
   ```bash
   git clone https://github.com/0d129/farming-hoyo-games-on-linux.git
   cd farming-hoyo-games-on-linux/genshin-bettergi
   cp config.example.sh config.sh
   nano config.sh
   ```
   设置 `GI_APPID`：游戏运行时执行 `xprop WM_CLASS`，再点击游戏窗口，会显示 `steam_app_<ID>`。如果目录在别处，还要设置 `GI_DIR`/`BGI_DIR`。
4. **退出 Steam**（Steam → 退出），然后运行：
   ```bash
   ./setup.sh
   ```
   `bgiconfig` 这一步需要 BetterGI 的 `User/config.json`，它在 BetterGI 第一次运行时生成。如果是全新的 BetterGI，先用 `bettergi.sh` 启动一次再关掉，然后运行 `./setup.sh bgiconfig`。

### 每一步做什么

| 步骤 | 内容 / 原因 |
|---|---|
| `copy` | 可选。用 `rsync` 把游戏和 BetterGI 从 `SRC_DIR` 复制到 `GAMES_DIR`。`SRC_DIR` 为空时跳过。 |
| `shortcut` | 把 Steam 快捷方式 `GI_APPID` 指向 `GI_DIR/GenshinImpact.exe`。只有在加入 Steam 之后又移动了游戏时才需要。**必须先退出 Steam**，否则 Steam 会覆盖修改。备份保存为 `shortcuts.vdf.bak-*`。 |
| `dotnet` | 在游戏前缀里安装 .NET 8 桌面运行时（教程第 4 步）。 |
| `fonts` | 确保前缀里有中文字体（微软雅黑、宋体）（教程第 3 步）。Proton 自带这些字体，所以直接链接过去。需要更多字体：`FONT_DIR=/路径 ./setup.sh fonts`。 |
| `registry` | 创建 `HKCU\Software\Classes`。没有它，BetterGI 在注册 `bettergi://` 链接协议时会崩溃。同时把该协议指向 `BGI_DIR`。 |
| `bgiconfig` | 把 BetterGI 的截图方式设为 `BitBlt`，因为默认方式需要的 `DwmGetDxSharedSurface` 在 Wine 里没有。同时把游戏路径设为 `GI_DIR`。备份保存为 `config.json.bak-*`。 |
| `launcher` | 把 `bettergi.sh` 链接到 `~/.local/bin`，之后在任何地方都能运行 `bettergi.sh`。 |

## 使用

1. 从 Steam 启动原神。
2. 运行 `bettergi.sh`，BetterGI 窗口会打开，用法和 Windows 上一样。
3. 在 BetterGI 里启动截图器和任务，然后点击游戏窗口。只要游戏不是当前焦点窗口，BetterGI 就会暂停（日志里会提示），所以运行期间保持游戏在最前面，不要动鼠标键盘。

日志：
- Wine / 启动脚本输出：`~/.cache/bettergi-wine.log`
- BetterGI 自己的日志：`BGI_DIR/log/`

## 原理 / 每一部分为什么需要

- **同一个前缀、同一个 wineserver。** BetterGI 用 Win32 窗口接口查找游戏，而这些接口只能看到同一个 wineserver 里的窗口。所以 `bettergi.sh` 使用游戏的前缀，并设置 `WINEFSYNC=1 WINEESYNC=1` 与 Proton 保持一致，Wine 才会连接到正在运行的 wineserver。`PROTON_DIR` 必须是游戏使用的那个 Proton。
- **`DOTNET_SYSTEM_GLOBALIZATION_USENLS=1`**，按官方教程设置。
- **不连接终端。** 如果 BetterGI 的标准输入/输出是 Linux 终端，它会在 `ConsoleHelper` 里崩溃（"Invalid function"），所以启动脚本把它们重定向到日志文件。

## 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| `bettergi.sh` 提示 `not found: …` | `config.sh` 里的路径不对，或者还没运行安装。 |
| 提示 `prefix … missing` | 先从 Steam 启动一次游戏（强制 Proton 9.0 (Beta)），让前缀生成。 |
| BetterGI 一启动就崩溃，提到注册表或 URL 协议 | 运行 `./setup.sh registry`。 |
| BetterGI 截不到游戏画面，或者画面是黑的 | 关闭 BetterGI 后运行 `./setup.sh bgiconfig`。截图方式必须是 `BitBlt`。 |
| BetterGI 找不到游戏窗口 | BetterGI 在另一个 wineserver 里。检查 `PROTON_DIR`，不要改 `WINEFSYNC`/`WINEESYNC`。 |
| 日志里有 `Fontconfig error: … out of memory` | 无害，可以忽略。 |

## 许可证

GPL-3.0（见 [LICENSE](../LICENSE)）。本仓库不包含 BetterGI 本身。
