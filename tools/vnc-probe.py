#!/usr/bin/env python3
"""Minimal VNC client for testing a hyprland-wsl session from a script.

It sees and does what a real viewer would: takes screenshots, moves the pointer, presses keys.

  vnc-probe.py PORT shot out.png            save a screenshot
  vnc-probe.py PORT move X Y                move the pointer
  vnc-probe.py PORT click X Y               move and left-click
  vnc-probe.py PORT key super+q             press a key combination
  vnc-probe.py PORT type "hello"            type text
  vnc-probe.py PORT hold SECONDS            stay connected, requesting updates (for load tests)
  vnc-probe.py PORT cursor                  the pointer image the server sends to viewers
  vnc-probe.py PORT latency N               time from a key press to the screen changing
  vnc-probe.py PORT fps SECONDS             screen updates per second and their spacing (start something
                                            moving first)

Several actions can be chained:  vnc-probe.py 5900 key super+q wait 2 shot after.png
Needs only the Python standard library. No authentication, 127.0.0.1 only.
"""
import socket, struct, sys, time, zlib

KEYS = {"super": 0xFFEB, "alt": 0xFFE9, "ctrl": 0xFFE3, "shift": 0xFFE1, "return": 0xFF0D,
        "enter": 0xFF0D, "tab": 0xFF09, "esc": 0xFF1B, "space": 0x20, "f4": 0xFFC1,
        "left": 0xFF51, "up": 0xFF52, "right": 0xFF53, "down": 0xFF54}


class Vnc:
    def __init__(self, port):
        s = self.s = socket.create_connection(("127.0.0.1", port), timeout=10)
        self.read(12)
        s.sendall(b"RFB 003.008\n")
        n = self.read(1)[0]
        types = self.read(n)
        if 1 not in types:
            sys.exit("server wants authentication")
        s.sendall(b"\x01")
        if struct.unpack(">I", self.read(4))[0] != 0:
            sys.exit("security handshake failed")
        s.sendall(b"\x01")                                   # shared session
        self.w, self.h = struct.unpack(">HH", self.read(4))
        self.read(16)
        self.read(struct.unpack(">I", self.read(4))[0])       # desktop name
        # 32 bits per pixel, little-endian, red in the low byte: R G B X in memory
        s.sendall(struct.pack(">BxxxBBBBHHHBBBxxx", 0, 32, 24, 0, 1, 255, 255, 255, 0, 8, 16))
        s.sendall(struct.pack(">BxHi", 2, 1, 0))             # raw encoding only

    def read(self, n):
        buf = bytearray()
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                sys.exit("server closed the connection")
            buf += chunk
        return bytes(buf)

    def skip_frame(self):
        """Request changes, wait for the update and throw the pixels away. Returns the pixel count.
        Much cheaper than frame(), so that counting updates measures the server, not this script."""
        if not hasattr(self, "scratch"):
            self.scratch = memoryview(bytearray(1 << 20))
        self.s.sendall(struct.pack(">BBHHHH", 3, 1, 0, 0, self.w, self.h))
        while True:
            kind = self.read(1)[0]
            if kind == 0:
                break
            if kind == 2:
                continue
            if kind == 3:
                self.read(3); self.read(struct.unpack(">I", self.read(4))[0]); continue
            sys.exit("unexpected server message %d" % kind)
        self.read(1)
        pixels = 0
        for _ in range(struct.unpack(">H", self.read(2))[0]):
            x, y, w, h, enc = struct.unpack(">HHHHi", self.read(12))
            if enc != 0:
                sys.exit("unexpected encoding %d" % enc)
            left = w * h * 4
            pixels += w * h
            while left:
                n = self.s.recv_into(self.scratch[:min(left, len(self.scratch))])
                if not n:
                    sys.exit("server closed the connection")
                left -= n
        return pixels

    def frame(self, incremental=0):
        """Request an update and return the framebuffer as rows of RGBX bytes."""
        if not hasattr(self, "fb"):
            self.fb = bytearray(self.w * self.h * 4)
        self.s.sendall(struct.pack(">BBHHHH", 3, incremental, 0, 0, self.w, self.h))
        while True:
            kind = self.read(1)[0]
            if kind == 0:
                break
            if kind == 2:                                     # bell
                continue
            if kind == 3:                                     # server cut text
                self.read(3); self.read(struct.unpack(">I", self.read(4))[0]); continue
            sys.exit("unexpected server message %d" % kind)
        self.read(1)
        for _ in range(struct.unpack(">H", self.read(2))[0]):
            x, y, w, h, enc = struct.unpack(">HHHHi", self.read(12))
            if enc != 0:
                sys.exit("unexpected encoding %d" % enc)
            data = self.read(w * h * 4)
            for row in range(h):
                o = ((y + row) * self.w + x) * 4
                self.fb[o:o + w * 4] = data[row * w * 4:(row + 1) * w * 4]
        return self.fb

    def shot(self, path):
        fb = self.frame()
        raw = bytearray()
        for row in range(self.h):
            line = fb[row * self.w * 4:(row + 1) * self.w * 4]
            raw.append(0)
            rgb = bytearray(self.w * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = line[0::4], line[1::4], line[2::4]
            raw += rgb

        def chunk(tag, body):
            return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)) +
                    chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))
        print("saved %s (%dx%d)" % (path, self.w, self.h))

    def pointer(self, x, y, buttons=0):
        self.s.sendall(struct.pack(">BBHH", 5, buttons, x, y))

    def keysym(self, sym, down):
        self.s.sendall(struct.pack(">BBxxI", 4, 1 if down else 0, sym))

    def combo(self, spec):
        syms = [KEYS.get(k.lower()) or ord(k) for k in spec.split("+")]
        for k in syms:
            self.keysym(k, True); time.sleep(0.05)
        for k in reversed(syms):
            self.keysym(k, False); time.sleep(0.05)


def main():
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit(__doc__)
    v = Vnc(int(a.pop(0)))
    while a:
        cmd = a.pop(0)
        if cmd == "shot":
            v.shot(a.pop(0))
        elif cmd in ("move", "click"):
            x, y = int(a.pop(0)), int(a.pop(0))
            v.pointer(x, y)
            if cmd == "click":
                time.sleep(0.1); v.pointer(x, y, 1); time.sleep(0.1); v.pointer(x, y)
        elif cmd == "key":
            v.combo(a.pop(0))
        elif cmd == "type":
            for ch in a.pop(0):
                v.keysym(ord(ch), True); v.keysym(ord(ch), False); time.sleep(0.03)
        elif cmd == "latency":
            # time from a key press to the next screen update, median of N tries
            times = []
            v.frame()
            for _ in range(int(a.pop(0))):
                time.sleep(0.4)
                v.s.settimeout(0.3)
                try:
                    while True:                      # drain updates that are still on their way
                        v.frame(incremental=1)
                except socket.timeout:
                    pass
                v.s.settimeout(5)
                t = time.time()
                v.keysym(ord("x"), True); v.keysym(ord("x"), False)
                v.frame(incremental=1)
                times.append((time.time() - t) * 1000)
            times.sort()
            print("key to screen: median %.0f ms, worst %.0f ms" % (times[len(times) // 2], times[-1]))
        elif cmd == "settle":
            # after the previous action: how many updates arrive, and for how long, until the
            # screen has been still for half a second (measures animations)
            v.frame()
            t = time.time(); n = 0; last = t
            v.s.settimeout(0.5)
            try:
                while time.time() - t < 15:
                    v.frame(incremental=1); n += 1; last = time.time()
            except socket.timeout:
                pass
            v.s.settimeout(10)
            dur = last - t
            print("settled after %.2f s, %d updates (%.0f per second)" % (dur, n, n / dur if dur > 0 else 0))
            return
        elif cmd == "fps":
            # screen updates per second while something is moving, and how even they are
            secs = float(a.pop(0)); n = 0; pixels = 0; gaps = []
            v.frame()
            v.s.settimeout(5)
            start = last = time.time()
            try:
                while last - start < secs:
                    pixels += v.skip_frame(); n += 1
                    now = time.time(); gaps.append(now - last); last = now
            except socket.timeout:
                pass
            dur = last - start
            gaps.sort()
            if n:
                print("updates per second: %.1f over %.1f s (gap between updates: median %.1f ms, 99th percentile %.1f ms, "
                      "worst %.1f ms; %.0f %% of the screen per update)"
                      % (n / dur, dur, gaps[n // 2] * 1000, gaps[min(n - 1, n * 99 // 100)] * 1000, gaps[-1] * 1000,
                         100.0 * pixels / n / (v.w * v.h)))
            else:
                print("no updates in %.0f s" % secs)
            return
        elif cmd == "cursor":
            # what pointer image does the server hand to a viewer that draws the pointer itself?
            # encodings: raw, cursor with alpha (what TigerVNC asks for), plain cursor
            v.s.sendall(struct.pack(">BxHiii", 2, 3, 0, -314, -239))
            if a and a[0] == "move":                 # "cursor move": also nudge the pointer first
                a.pop(0); v.pointer(v.w // 2, v.h // 2); time.sleep(0.3); v.pointer(v.w // 2 + 5, v.h // 2 + 5)
            v.s.settimeout(3)
            found = False
            try:
                for _ in range(6):
                    v.s.sendall(struct.pack(">BBHHHH", 3, 0 if _ == 0 else 1, 0, 0, v.w, v.h))
                    while v.read(1)[0] != 0:
                        pass
                    v.read(1)
                    for _r in range(struct.unpack(">H", v.read(2))[0]):
                        x, y, w, h, enc = struct.unpack(">HHHHi", v.read(12))
                        if enc == -314:
                            v.read(4)
                            px = v.read(w * h * 4)
                            opaque = sum(1 for i in range(3, len(px), 4) if px[i] > 127)
                            dark = sum(1 for i in range(0, len(px), 4) if px[i] < 16 and px[i + 1] < 16 and px[i + 2] < 16)
                            print("pointer image with alpha %dx%d, hotspot %d,%d: %d of %d pixels opaque, %d black"
                                  % (w, h, x, y, opaque, w * h, dark))
                            found = True
                        elif enc == -239:
                            px = v.read(w * h * 4); mask = v.read(((w + 7) // 8) * h)
                            shown = sum(bin(b).count("1") for b in mask)
                            dark = sum(1 for i in range(0, len(px), 4) if px[i] < 16 and px[i + 1] < 16 and px[i + 2] < 16)
                            print("pointer image %dx%d, hotspot %d,%d: %d of %d pixels visible, %d of all pixels black"
                                  % (w, h, x, y, shown, w * h, dark))
                            found = True
                        elif enc == 0:
                            left = w * h * 4
                            while left:
                                left -= len(v.read(min(left, 1 << 20)))
                        else:
                            sys.exit("unexpected encoding %d" % enc)
                    if found:
                        break
            except socket.timeout:
                pass
            if not found:
                print("the server sent no pointer image")
            return
        elif cmd == "wait":
            time.sleep(float(a.pop(0)))
        elif cmd == "hold":
            end = time.time() + float(a.pop(0)); n = 0
            v.frame()
            # like a real viewer: ask for changes only, and wait for the server to answer
            try:
                while time.time() < end:
                    v.s.settimeout(max(end - time.time(), 0.1))
                    v.frame(incremental=1); n += 1
            except socket.timeout:
                pass
            print("updates received: %d" % n)
            return
        else:
            sys.exit("unknown action " + cmd)
        time.sleep(0.2)


main()
