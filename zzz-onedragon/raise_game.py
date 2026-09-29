#!/usr/bin/env python3
"""Raise and focus the game window (matched by X11 WM_CLASS) via EWMH _NET_ACTIVE_WINDOW (source=pager, so KDE allows it)."""
import ctypes
import ctypes.util
import sys

if len(sys.argv) != 2:
    sys.exit('usage: raise_game.py steam_app_<APPID>')
WM_CLASS = sys.argv[1]

x = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11'))
x.XOpenDisplay.restype = ctypes.c_void_p
x.XDefaultRootWindow.restype = ctypes.c_ulong
x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x.XInternAtom.restype = ctypes.c_ulong
x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
x.XGetWindowProperty.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_long, ctypes.c_long,
                                 ctypes.c_int, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
                                 ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_ulong),
                                 ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_void_p)]


class XClientMessageEvent(ctypes.Structure):
    _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                ('format', ctypes.c_int), ('data', ctypes.c_long * 5)]


class XClassHint(ctypes.Structure):
    _fields_ = [('res_name', ctypes.c_char_p), ('res_class', ctypes.c_char_p)]


class XEvent(ctypes.Union):
    _fields_ = [('xclient', XClientMessageEvent), ('pad', ctypes.c_long * 24)]


dpy = x.XOpenDisplay(None)
if not dpy:
    sys.exit('cannot open X display')
root = x.XDefaultRootWindow(dpy)


def prop_windows(win: int, name: bytes) -> list[int]:
    atype, fmt, n, after = ctypes.c_ulong(), ctypes.c_int(), ctypes.c_ulong(), ctypes.c_ulong()
    data = ctypes.c_void_p()
    x.XGetWindowProperty(dpy, win, x.XInternAtom(dpy, name, 0), 0, 4096, 0, 33,  # XA_WINDOW
                         ctypes.byref(atype), ctypes.byref(fmt), ctypes.byref(n), ctypes.byref(after),
                         ctypes.byref(data))
    if not data.value:
        return []
    return list(ctypes.cast(data, ctypes.POINTER(ctypes.c_ulong))[:n.value])


target = None
for w in prop_windows(root, b'_NET_CLIENT_LIST'):
    hint = XClassHint()
    if x.XGetClassHint(dpy, ctypes.c_ulong(w), ctypes.byref(hint)) and hint.res_class == WM_CLASS.encode():
        target = w
        break
if target is None:
    sys.exit(f'game window ({WM_CLASS}) not found')

ev = XEvent()
ev.xclient.type = 33  # ClientMessage
ev.xclient.send_event = 1
ev.xclient.window = target
ev.xclient.message_type = x.XInternAtom(dpy, b'_NET_ACTIVE_WINDOW', 0)
ev.xclient.format = 32
ev.xclient.data[0] = 2  # source indication: pager
mask = (1 << 20) | (1 << 19)  # SubstructureRedirect | SubstructureNotify
x.XSendEvent(dpy, ctypes.c_ulong(root), 0, ctypes.c_long(mask), ctypes.byref(ev))
x.XFlush(dpy)
print(f'raised game window 0x{target:x}')
