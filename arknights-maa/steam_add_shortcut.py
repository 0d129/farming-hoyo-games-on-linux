#!/usr/bin/env python3
"""Add (or update) a Steam non-Steam shortcut and force a compatibility tool for it.

Usage: steam_add_shortcut.py <shortcuts.vdf> <config.vdf> <name> <exe> <launch options> <compat tool>
The app ID is the one Steam itself derives from exe + name, so re-running finds the same shortcut.
Steam must be closed, or it overwrites both files on exit.
"""
import re
import shutil
import struct
import sys
import time
import zlib


def parse(b, i=0):
    """Binary VDF -> dict (maps), str, or int."""
    d = {}
    while True:
        t = b[i]; i += 1
        if t == 8:
            return d, i
        j = b.index(b'\0', i); key = b[i:j].decode(); i = j + 1
        if t == 0:
            d[key], i = parse(b, i)
        elif t == 1:
            j = b.index(b'\0', i); d[key] = b[i:j].decode(); i = j + 1
        elif t == 2:
            d[key] = struct.unpack_from('<I', b, i)[0]; i += 4
        else:
            raise ValueError(f'unsupported VDF type {t} at {i - 1}')


def dump(d):
    out = b''
    for k, v in d.items():
        kb = k.encode() + b'\0'
        if isinstance(v, dict):
            out += b'\0' + kb + dump(v)
        elif isinstance(v, int):
            out += b'\2' + kb + struct.pack('<I', v)
        else:
            out += b'\1' + kb + v.encode() + b'\0'
    return out + b'\x08'


def backup(path):
    shutil.copy2(path, f'{path}.bak-{time.strftime("%Y%m%d-%H%M%S")}')


def main():
    shortcuts, config, name, exe, launch, tool = sys.argv[1:7]
    exe_q = f'"{exe}"'
    appid = (zlib.crc32((exe_q + name).encode()) | 0x80000000) & 0xFFFFFFFF

    root, _ = parse(open(shortcuts, 'rb').read())
    sc = root['shortcuts']
    entry = next((s for s in sc.values() if s.get('Exe') == exe_q), None)
    if entry is None:
        entry = sc[str(len(sc))] = {
            'appid': appid, 'AppName': name, 'Exe': exe_q, 'StartDir': f'"{exe.rsplit("/", 1)[0]}/"',
            'icon': '', 'ShortcutPath': '', 'LaunchOptions': '', 'IsHidden': 0, 'AllowDesktopConfig': 1,
            'AllowOverlay': 1, 'OpenVR': 0, 'Devkit': 0, 'DevkitGameID': '', 'DevkitOverrideAppID': 0,
            'LastPlayTime': 0, 'FlatpakAppID': '', 'sortas': '', 'tags': {}}
        print(f'added shortcut "{name}" (app ID {appid})')
    appid = entry['appid']
    entry['LaunchOptions'] = launch
    backup(shortcuts)
    open(shortcuts, 'wb').write(dump(root))
    print(f'launch options: {launch}')

    cfg = open(config, encoding='utf-8').read()
    m = re.search(r'\n(\t*)"CompatToolMapping"\n\t*\{\n', cfg)
    end, depth = m.end(), 1   # end of the CompatToolMapping block
    while depth:
        depth += {'{': 1, '}': -1}.get(cfg[end], 0); end += 1
    block = cfg[m.end():end]
    if f'"{appid}"' in block:
        block = re.sub(rf'("{appid}"\s*\{{\s*"name"\s*)"[^"]*"', rf'\g<1>"{tool}"', block, count=1)
    else:
        ind = m.group(1) + '\t'
        block = (f'{ind}"{appid}"\n{ind}{{\n{ind}\t"name"\t\t"{tool}"\n'
                 f'{ind}\t"config"\t\t""\n{ind}\t"priority"\t\t"250"\n{ind}}}\n' + block)
    cfg = cfg[:m.end()] + block + cfg[end:]
    backup(config)
    open(config, 'w', encoding='utf-8').write(cfg)
    print(f'compatibility tool: {tool}')


if __name__ == '__main__':
    main()
