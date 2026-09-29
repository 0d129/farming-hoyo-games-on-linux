# 在 Linux 上运行绝区零一条龙

[English](README.md) | 简体中文

在 Linux 上运行 [绝区零一条龙（ZenlessZoneZero-OneDragon）](https://github.com/OneDragon-Anything/ZenlessZoneZero-OneDragon)，游戏通过 Steam + Proton 运行。

一条龙是 Windows 程序。这里用它自带的 Windows 版 Python，**以无界面方式**运行在**和游戏同一个 Proton 前缀、同一个 wineserver** 里。这样它能找到游戏窗口、截图和发送按键，和在 Windows 上一样。

不修改一条龙源码，所有内容都在三个小脚本里：

| 文件 | 作用 |
|---|---|
| `zzz-od.sh` | 启动脚本。设置 Wine 环境，把游戏窗口切到前台，启动一条龙。 |
| `bootstrap.py` | 从一条龙目录加载程序，强制使用 BitBlt 截图，增加 `test` 自检模式。 |
| `raise_game.py` | 从 X11 一侧把游戏窗口切到前台（Wine 自己的调用会被 KDE 拦下）。 |
| `config.example.sh` | 复制为 `config.sh`，填写你的路径。 |

## 测试环境

- Ubuntu，内核 7.0，KDE Plasma（**X11**），AMD Radeon 680M
- Steam，**Proton 9.0 (Beta)**，游戏分辨率 1920×1080
- 一条龙提交 `8b52af8`（自带 Python 3.11.12）

未测试 Wayland。`raise_game.py` 直接和 X 服务器通信，在 Wayland 下可能只对 XWayland 窗口有效，也可能完全无效。

## 安装

### 1. 游戏：把 ZenlessZoneZero.exe 加入 Steam

准备一份 Windows 版游戏目录：可以从已有的 Windows 安装复制，也可以用 Proton 运行米哈游启动器（HoYoPlay）下载。

**把游戏放在 Linux 文件系统（ext4、btrfs）上，不要放在 NTFS 盘上。** 原因见[NTFS 注意事项](../README.zh-CN.md#注意事项)。

在 Steam 中：**游戏 → 添加非 Steam 游戏** → 选择 `ZenlessZoneZero.exe`。然后在 **属性 → 兼容性** 中强制使用 **Proton 9.0 (Beta)**，并启动一次游戏，让 Steam 创建前缀。

查找这个快捷方式的 app ID：游戏运行时执行 `xprop WM_CLASS`，再点击游戏窗口，会显示 `steam_app_<ID>`。前缀位置是 `~/.steam/steam/steamapps/compatdata/<ID>/pfx`。

### 2. 一条龙：准备一个已安装好的目录

需要一个已经完成安装的一条龙目录，即里面有 `.install/python/...` 和 `.venv/`。

测试过的做法：**在 Windows 上安装并配置好一条龙**，然后把整个目录复制到 Linux（例如 `~/Games/ZZZ_OD`）。配置（账号、实例、要刷的内容）都在 `config/` 里，会一起复制过来。`.venv` 里记录的 Windows 路径不影响使用，`bootstrap.py` 会直接加载依赖包。

未测试的做法：在游戏前缀里用 Proton 运行 `OneDragon-Installer.exe`。

### 3. 放入原生 `ucrtbase.dll`

Proton 自带的 `ucrtbase.dll` 缺少 numpy 需要的 `crealf`，一条龙导入时会报错。把微软的 64 位 `ucrtbase.dll` 放到 **`python.exe` 同一目录**：

```
<一条龙目录>/.install/python/cpython-3.11.12-windows-x86_64-none/ucrtbase.dll
```

可以从 Windows 10/11 电脑的 `C:\Windows\System32\ucrtbase.dll` 复制（测试版本：10.0.19041.685）。这是微软的文件，所以本仓库不附带。启动脚本设置了 `WINEDLLOVERRIDES=ucrtbase=n,b`，只有能找到这个文件的进程才会使用它，游戏仍用 Proton 自带的版本。

### 4. 下载脚本

```bash
git clone https://github.com/0d129/farming-hoyo-games-on-linux.git
cd farming-hoyo-games-on-linux/zzz-onedragon
cp config.example.sh config.sh
nano config.sh          # 填写 ZZZ_APPID 和 OD_DIR
```

如果你的 Proton 不是默认 Steam 库中的 `Proton 9.0 (Beta)`，还要设置 `PROTON_DIR`。它必须是**游戏正在使用的那个 Proton**，否则一条龙会启动另一个 wineserver，找不到游戏窗口。

## 使用

1. 从 Steam 启动绝区零，等到标题画面或主界面。
2. 运行自检：
   ```bash
   ./zzz-od.sh test
   ```
   它会把游戏切到前台、截一张图、做 OCR，然后输出 `PASS` 或 `FAIL`。截图保存在 `<一条龙目录>/.debug/linux_selftest.png`，打开确认截到的是游戏画面。
3. 运行一条龙：
   ```bash
   ./zzz-od.sh run -i 1       # 运行实例 1；多个实例用 -i 1,2
   ./zzz-od.sh run -i 1 -c    # 完成后关闭游戏
   ```

运行期间**不要动鼠标键盘，也不要切换窗口**。和 Windows 上一样，输入会发给最前面的窗口。日志在 `<一条龙目录>/.log/`。

想当作命令使用：`ln -s "$PWD/zzz-od.sh" ~/.local/bin/zzz-od`。

## 原理 / 每一部分为什么需要

- **同一个前缀、同一个 wineserver。** 一条龙用 Win32 窗口接口查找游戏，而这些接口只能看到同一个 wineserver 里的窗口。所以 `WINEPREFIX` 指向游戏的前缀，`WINEFSYNC`/`WINEESYNC` 和 Proton 保持一致，Wine 才会连接到正在运行的 wineserver，而不是报错或另起一个。
- **BitBlt 截图。** `bootstrap.py` 强制使用 `bitblt` 截图方式（可用 `ZZZ_OD_SCREENSHOT=...` 改），不修改 `env.yml`，同一个目录拿回 Windows 仍能用。BitBlt 复制的是游戏区域在*屏幕上*显示的内容，所以游戏窗口不能被遮挡。
- **切换窗口到前台。** 一条龙会调用 `SetForegroundWindow`，但 KDE 的防抢焦点机制会忽略来自 Wine 的这个请求。`raise_game.py` 以任务栏（pager）身份发送 EWMH `_NET_ACTIVE_WINDOW` 请求，KDE 会执行。如果游戏仍不在前台，自检会失败，不会因为游戏被遮挡而误报 `PASS`。
- **`ucrtbase` 替换。** 见第 3 步。

## 常见问题

| 现象 | 原因 / 解决 |
|---|---|
| `game window (steam_app_…) not found` | 游戏没运行，或 `ZZZ_APPID` 填错。用 `xprop WM_CLASS` 确认。 |
| OCR 加载后显示 `FAIL: game window not found` | 一条龙在另一个 wineserver 里。`PROTON_DIR` 必须是游戏用的 Proton；不要改 `WINEFSYNC`/`WINEESYNC`。 |
| numpy 导入报错，提到 `crealf` | `python.exe` 旁边缺少原生 `ucrtbase.dll`（第 3 步）。 |
| 截图是终端而不是游戏 | 游戏被遮挡。现在的自检会发现这种情况；保持游戏在最前面。 |
| 游戏启动后一直黑屏，`Player.log` 里有 `IOException: Win32 IO returned 998` | 游戏文件损坏或无法写入（见注意事项）。把游戏移到 Linux 文件系统上。 |

游戏的 Unity 日志在 `<前缀>/drive_c/users/steamuser/AppData/LocalLow/miHoYo/ZenlessZoneZero/Player.log`。

## 注意事项

请先阅读[通用注意事项](../README.zh-CN.md#注意事项)，尤其是：**不要从用 `ntfs3` 挂载的 NTFS 盘运行游戏**。

## 许可证

GPL-3.0（见 [LICENSE](../LICENSE)），与一条龙相同。
