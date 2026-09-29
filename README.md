# Farming HoYoverse games on Linux

English | [简体中文](README.zh-CN.md)

Guides and scripts for running Windows auto-farming tools for HoYoverse games on Linux, with the games running under Steam + Proton.

| Game | Tool | Status | Guide |
|---|---|---|---|
| Zenless Zone Zero | [ZenlessZoneZero-OneDragon](https://github.com/OneDragon-Anything/ZenlessZoneZero-OneDragon) | Working | [zzz-onedragon/](zzz-onedragon/README.md) |
| Genshin Impact | [BetterGI](https://github.com/babalae/better-genshin-impact) | Working | [genshin-bettergi/](genshin-bettergi/README.md) |

The approach is the same for each tool: the tool runs with Wine **inside the same Proton prefix and wineserver as the game**, so it can find the game window, take screenshots and send input as it would on Windows. The tools' own source is not modified.

## Warnings

- **Don't run games from an NTFS drive mounted with the kernel `ntfs3` driver.** In testing (kernel 7.0), the laptop froze with `kernel BUG at fs/iomap/buffered-io.c` shortly after a game started writing to an `ntfs3` volume. After the reboot, several game files were corrupt and could neither be read nor deleted, and the game hung on a black screen. Keeping games and tools on a Linux file system (ext4, btrfs) avoids this.

  If you must use an NTFS drive (for example one shared with Windows), mount it with `ntfs-3g` instead. For the desktop auto-mounter (udisks2):
  ```
  # /etc/udisks2/mount_options.conf
  [defaults]
  ntfs_drivers=ntfs-3g
  ```
  Then unmount and remount the drive; `mount` should show it as `fuseblk`. If an NTFS drive gets damaged, only Windows `chkdsk X: /f` properly repairs it.
- **Using automation tools may violate the games' terms of service.** Use at your own risk.

## License

GPL-3.0 (see [LICENSE](LICENSE)). The tools themselves are not included.
