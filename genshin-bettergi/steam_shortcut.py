#!/usr/bin/env python3
"""Point a Steam non-Steam shortcut at a new exe, keeping its appid (and so its Proton prefix).

Usage: steam_shortcut.py <shortcuts.vdf> <appid> <exe path>
Steam must be closed, or it overwrites shortcuts.vdf on exit.
"""
import os
import shutil
import struct
import sys
import time

MAP, STR, INT, END = 0, 1, 2, 8


def parse(b, i=0):
    """Binary VDF -> list of (type, key, value); value is a list for maps."""
    out = []
    while True:
        t = b[i]; i += 1
        if t == END:
            return out, i
        j = b.index(b'\0', i); key = b[i:j]; i = j + 1
        if t == MAP:
            v, i = parse(b, i)
        elif t == STR:
            j = b.index(b'\0', i); v = b[i:j]; i = j + 1
        elif t == INT:
            v = b[i:i + 4]; i += 4
        else:
            raise ValueError(f'unsupported VDF type {t} at {i - 1}')
        out.append((t, key, v))


def dump(items):
    b = bytearray()
    for t, key, v in items:
        b += bytes([t]) + key + b'\0'
        b += dump(v) if t == MAP else (v + b'\0' if t == STR else v)
    return bytes(b + bytes([END]))


def main():
    path, appid, exe = sys.argv[1], int(sys.argv[2]), os.path.abspath(sys.argv[3])
    data = open(path, 'rb').read()
    root, _ = parse(data)
    entries = root[0][2]  # "shortcuts" map
    for _, _, entry in entries:
        fields = {k.lower(): n for n, (_, k, _) in enumerate(entry)}
        if struct.unpack('<I', entry[fields[b'appid']][2])[0] != appid:
            continue
        new = {b'exe': f'"{exe}"', b'startdir': f'"{os.path.dirname(exe)}/"'}
        for k, v in new.items():
            t, key, old = entry[fields[k]]
            entry[fields[k]] = (t, key, v.encode())
            print(f'{key.decode()}: {old.decode(errors="replace")} -> {v}')
        break
    else:
        sys.exit(f'no shortcut with appid {appid} in {path}')
    out = dump(root)
    if out == data:
        print('already up to date')
        return
    shutil.copy2(path, f'{path}.bak-{time.strftime("%Y%m%d-%H%M%S")}')
    open(path, 'wb').write(out)


if __name__ == '__main__':
    main()
