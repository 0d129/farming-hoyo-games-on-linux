# 在 Linux 上挂机米哈游游戏

[English](README.md) | 简体中文

在 Linux 上运行米哈游游戏的 Windows 自动化工具，游戏通过 Steam + Proton 运行。这里提供教程和脚本。

| 游戏 | 工具 | 状态 | 教程 |
|---|---|---|---|
| 绝区零 | [绝区零一条龙（ZenlessZoneZero-OneDragon）](https://github.com/OneDragon-Anything/ZenlessZoneZero-OneDragon) | 可用 | [zzz-onedragon/](zzz-onedragon/README.zh-CN.md) |
| 原神 | [BetterGI](https://github.com/babalae/better-genshin-impact) | 可用 | [genshin-bettergi/](genshin-bettergi/README.zh-CN.md) |
| 两者串联定时运行 | [farm-chain](farm-chain/README.zh-CN.md)：依次运行上面两个（cron） | 可用 | [farm-chain/](farm-chain/README.zh-CN.md) |

每个工具的思路相同：用 Wine 把工具运行在**和游戏同一个 Proton 前缀、同一个 wineserver 里**，这样它能找到游戏窗口、截图和发送按键，和在 Windows 上一样。不修改工具本身的源码。

## 注意事项

- **不要从用内核 `ntfs3` 驱动挂载的 NTFS 盘运行游戏。** 测试时（内核 7.0），游戏开始写入 `ntfs3` 盘后不久，笔记本就死机了，日志显示 `kernel BUG at fs/iomap/buffered-io.c`。重启后有几个游戏文件损坏，既读不了也删不掉，游戏卡在黑屏。把游戏和工具放在 Linux 文件系统（ext4、btrfs）上可以避免。

  如果一定要用 NTFS 盘（例如和 Windows 共用的盘），改用 `ntfs-3g` 挂载。桌面自动挂载（udisks2）的设置：
  ```
  # /etc/udisks2/mount_options.conf
  [defaults]
  ntfs_drivers=ntfs-3g
  ```
  然后卸载再重新挂载，`mount` 应显示为 `fuseblk`。NTFS 盘一旦损坏，只有 Windows 的 `chkdsk X: /f` 能正确修复。
- **使用自动化工具可能违反游戏用户协议**，风险自负。

## 许可证

GPL-3.0（见 [LICENSE](LICENSE)）。本仓库不包含这些工具本身。
