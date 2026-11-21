"""Optional global shortcuts on an X11 desktop; no keyboard monitoring."""
import ctypes as C
import ctypes.util
import os

from PySide6.QtCore import QTimer


class XKeyEvent(C.Structure):
    _fields_ = [("type", C.c_int), ("serial", C.c_ulong), ("send_event", C.c_int),
                ("display", C.c_void_p), ("window", C.c_ulong), ("root", C.c_ulong),
                ("subwindow", C.c_ulong), ("time", C.c_ulong), ("x", C.c_int),
                ("y", C.c_int), ("x_root", C.c_int), ("y_root", C.c_int),
                ("state", C.c_uint), ("keycode", C.c_uint), ("same_screen", C.c_int)]


class XEvent(C.Union):
    _fields_ = [("type", C.c_int), ("key", XKeyEvent), ("pad", C.c_long * 24)]


class GlobalHotkeys:
    def __init__(self, workspace):
        self.display = None
        self.library = None
        self.timer = QTimer(workspace)
        self.callbacks = {}
        self.grabs = []
        self.available = False
        # XWayland cannot provide reliable desktop-wide shortcuts to native Wayland apps.
        if os.environ.get("XDG_SESSION_TYPE") == "wayland" or not os.environ.get("DISPLAY"):
            return
        name = ctypes.util.find_library("X11")
        if not name:
            return
        try:
            lib = self.library = C.CDLL(name)
            declarations = {
                "XOpenDisplay": ([C.c_char_p], C.c_void_p),
                "XDefaultRootWindow": ([C.c_void_p], C.c_ulong),
                "XStringToKeysym": ([C.c_char_p], C.c_ulong),
                "XKeysymToKeycode": ([C.c_void_p, C.c_ulong], C.c_ubyte),
                "XGrabKey": ([C.c_void_p, C.c_int, C.c_uint, C.c_ulong, C.c_int, C.c_int, C.c_int], C.c_int),
                "XUngrabKey": ([C.c_void_p, C.c_int, C.c_uint, C.c_ulong], C.c_int),
                "XPending": ([C.c_void_p], C.c_int),
                "XNextEvent": ([C.c_void_p, C.POINTER(XEvent)], C.c_int),
                "XSync": ([C.c_void_p, C.c_int], C.c_int),
                "XCloseDisplay": ([C.c_void_p], C.c_int),
                "XSetErrorHandler": ([C.c_void_p], C.c_void_p),
            }
            for key, (args, result) in declarations.items():
                method = getattr(lib, key)
                method.argtypes, method.restype = args, result
            self.display = lib.XOpenDisplay(None)
            if not self.display:
                return
            self.root = lib.XDefaultRootWindow(self.display)
            failed = []
            callback_type = C.CFUNCTYPE(C.c_int, C.c_void_p, C.c_void_p)
            error_handler = callback_type(lambda display, event: failed.append(True) or 0)
            previous = lib.XSetErrorHandler(C.cast(error_handler, C.c_void_p))
            try:
                for keysym, callback in ((b"p", workspace.toggle_panel), (b"space", workspace.toggle_play),
                    (b"Up", lambda: workspace.navigate(False)), (b"Down", lambda: workspace.navigate(True)),
                    (b"e", workspace.show_editor)):
                    code = int(lib.XKeysymToKeycode(self.display, lib.XStringToKeysym(keysym)))
                    if not code:
                        failed.append(True)
                        continue
                    self.callbacks[code] = callback
                    # Control + Mod1 (Alt), with Caps Lock / Num Lock variations.
                    for locks in (0, 2, 16, 18):
                        modifiers = 4 | 8 | locks
                        lib.XGrabKey(self.display, code, modifiers, self.root, False, 1, 1)
                        self.grabs.append((code, modifiers))
                lib.XSync(self.display, False)
            finally:
                lib.XSetErrorHandler(previous)
            if failed:
                self.close()
                workspace.notice.setText("Global shortcuts unavailable or already in use. Ctrl + Alt shortcuts still work while SmartNotch is focused.")
                return
            self.available = True
            workspace.notice.setText("Global shortcuts · Ctrl + Alt + P: panel · Space: play/pause · ↑ / ↓: navigate · E: editor")
            self.timer.timeout.connect(self.poll)
            self.timer.start(40)
        except (OSError, AttributeError):
            self.close()

    def poll(self):
        if not self.display:
            return
        # Drain a bounded batch to keep UI updates responsive.
        for _ in range(min(32, self.library.XPending(self.display))):
            event = XEvent()
            self.library.XNextEvent(self.display, C.byref(event))
            if event.type == 2:
                callback = self.callbacks.get(event.key.keycode)
                if callback:
                    callback()

    def close(self):
        self.timer.stop()
        if self.display:
            for code, modifiers in self.grabs:
                self.library.XUngrabKey(self.display, code, modifiers, self.root)
            self.library.XCloseDisplay(self.display)
            self.display = None
        self.available = False
