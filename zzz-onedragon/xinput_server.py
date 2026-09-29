#!/usr/bin/env python3
"""Perform OneDragon's mouse clicks from the X11 side via XTest.

In the ZZZ open world the game locks the cursor, and under Wine it ignores clicks injected
from inside Wine (SendInput), even with ALT held. A real X11 click with ALT held works, so
bootstrap.py forwards OneDragon's win_click() here over a local TCP socket.

Protocol, one line per request:  click <x> <y> <press_seconds> <primary 0|1> [alt 0|1]  ->  "ok"
Coordinates are screen coordinates (the same in Wine and X11 on a single, unscaled screen).
Usage: xinput_server.py <port>
"""
import ctypes
import ctypes.util
import socketserver
import sys
import time

x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xtst'))
x11.XOpenDisplay.restype = ctypes.c_void_p
dpy = ctypes.c_void_p(x11.XOpenDisplay(None))
if not dpy.value:
    sys.exit('cannot open X display')
ALT = x11.XKeysymToKeycode(dpy, 0xffe9)  # Alt_L


def flush() -> None:
    x11.XFlush(dpy)


def click(x: int, y: int, press: float, primary: bool, alt: bool = True) -> None:
    button = 1 if primary else 3
    # ALT frees the cursor in the open world; a real motion event (not just a warp) is needed
    # before the game accepts the click at the new position.
    if alt:
        xtst.XTestFakeKeyEvent(dpy, ALT, 1, 0); flush(); time.sleep(0.05)
    xtst.XTestFakeMotionEvent(dpy, -1, x - 5, y, 0); flush(); time.sleep(0.02)
    xtst.XTestFakeMotionEvent(dpy, -1, x, y, 0); flush(); time.sleep(0.05)
    xtst.XTestFakeButtonEvent(dpy, button, 1, 0); flush(); time.sleep(max(0.05, press))
    xtst.XTestFakeButtonEvent(dpy, button, 0, 0); flush(); time.sleep(0.03)
    if alt:
        xtst.XTestFakeKeyEvent(dpy, ALT, 0, 0); flush()


class Handler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        for line in self.rfile:
            parts = line.decode().split()
            if len(parts) in (5, 6) and parts[0] == 'click':
                click(int(float(parts[1])), int(float(parts[2])), float(parts[3]), parts[4] == '1',
                      len(parts) == 5 or parts[5] == '1')
                self.wfile.write(b'ok\n')
            else:
                self.wfile.write(b'error\n')


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('127.0.0.1', int(sys.argv[1])), Handler) as server:
    server.serve_forever()
