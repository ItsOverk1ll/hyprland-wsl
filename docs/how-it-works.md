# How it works

Why Hyprland does not simply start under WSL2, and what each part of this project does about it.

## The two problems

**No usable GPU device.** Hyprland's backend library, aquamarine, allocates its buffers through
GBM, which needs a DRM device under `/dev/dri`. WSL2 exposes the GPU as `/dev/dxg` instead, a
different interface that aquamarine cannot use. Without a DRM device Hyprland stops with
"no allocator available".

**WSLg cannot host it.** Hyprland can run as a window inside another Wayland compositor. WSLg has
one, but it only accepts shared-memory buffers and lacks `zwp_linux_dmabuf_v1`, which aquamarine's
nested mode requires. Hyprland stops with "Wayland backend cannot start: Missing protocols".

## The stack

```
Windows desktop
└─ TigerVNC viewer               a WSLg window, or a viewer running on Windows itself
   └─ wayvnc                     VNC server on 127.0.0.1, attached to Hyprland
labwc                            headless host compositor, software OpenGL
└─ Hyprland                      nested in labwc, using the patched aquamarine
   └─ your apps
vgem                             virtual DRM device in the WSL kernel
```

### vgem: a DRM device

The WSL kernel ships the `vgem` module. Loading it creates `/dev/dri/card0` and
`/dev/dri/renderD128`. It has no display outputs and does no rendering, but it can allocate
buffers, which is all that is needed here. Rendering is done on the CPU by Mesa's llvmpipe.

One detail: on vgem, GBM allocates "dumb buffers", and the kernel refuses that request on render
nodes. Both labwc and Hyprland open the render node. The launcher therefore replaces
`/dev/dri/renderD128` with a device node that carries the primary node's numbers, so opening the
render node path reaches the primary node.

All WSL distros share one kernel, so this part is identical on every distro.

### labwc: a host Hyprland can nest in

labwc is a small wlroots-based compositor that provides the dmabuf protocol. It runs headless: it
has a virtual screen and no window of its own, because it could not present to WSLg either. It is
configured to show Hyprland's window maximised and without decorations, so its screen is exactly
Hyprland's screen.

### The patched aquamarine

Under a headless wlroots host, aquamarine's nested mode has bugs that keep Hyprland from getting a
monitor. The patches in [`../patches/`](../patches/) fix them:

1. The first commit of Hyprland's window is never sent, because aquamarine only flushes its
   connection when the host sends something, and a headless host with no input devices stays
   silent. Hyprland then has no monitor.
2. Hyprland draws its first frame before acknowledging the host's configure event. wlroots hosts
   treat that as a protocol error and close the connection.
3. aquamarine asks for newer protocol versions than older hosts offer (labwc 0.7 on Ubuntu 24.04
   and Linux Mint 22), which also ends the connection.
4. In aquamarine 0.10 only: queued callbacks are run from a loop that is modified while it runs,
   which crashes Hyprland once fix 2 is in place.

The installer builds a patched copy of the same aquamarine version the distro ships and puts it in
`/opt/hyprland-wsl`. The distro's own package stays as it is.

### A private mount namespace

The launcher starts labwc and Hyprland in their own mount namespace, a view of the filesystem that
only those processes and their children have. Two things differ in it:

- The patched aquamarine is mounted over the system's copy. Pointing `LD_LIBRARY_PATH` at it would
  be simpler, but Debian-family packages give the Hyprland binary a file capability, and the
  dynamic loader ignores `LD_LIBRARY_PATH` for such programs.
- `/tmp/.X11-unix` is an empty directory with normal permissions. WSLg mounts its own there with
  permissions that Xwayland setup rejects; some labwc versions refuse to start because of it.

Nothing outside the session sees either change.

### wayvnc and the viewer

wayvnc shares Hyprland's screen over VNC, on localhost only, and feeds keyboard and mouse back
into Hyprland as virtual input devices. It attaches to Hyprland rather than to labwc, so keys do
not pass labwc's own shortcuts on the way (labwc would keep Alt+Tab, Alt+F4, Super+Return and
others for itself), and labwc has nothing to do while the picture is still.

There are two ways to look at it:

- **The WSLg window.** By default the launcher starts TigerVNC's viewer inside WSL. It is an X11
  program, and WSLg shows X11 programs as normal windows on the Windows desktop. Simple, but
  Windows handles the Windows key, Alt+Tab and the like before WSLg gets them.
- **A viewer on Windows.** WSL forwards `127.0.0.1` ports to Windows, so a VNC viewer running
  on Windows can connect to the same server. In full screen, TigerVNC's Windows viewer captures
  the whole keyboard, which makes the Windows key usable as Hyprland's SUPER.
  `windows\hyprland-wsl.ps1` does this: it starts the session with `--no-viewer`, runs the
  viewer, and ends the session when the viewer closes.

One trap the launcher has to avoid: X servers also listen on a socket name that is shared by
everything in WSL, across distros and mount namespaces, and X programs try that name first. If one
of the compositors' own Xwayland servers became display `:0`, the viewer inside WSL would connect
to it instead of to WSLg and open its window inside the very session it is showing. The launcher
therefore mounts WSLg's sockets into the private `/tmp/.X11-unix`, so the compositors see `:0` as
taken and pick another number.

### Software rendering threads

Mesa's software renderer starts one thread per CPU core. Under WSL that turned out to cost far
more CPU than it gains: on a 24-core machine the same frames took over ten times the CPU with 24
threads as with one. The launcher caps it at 4 (`LP_NUM_THREADS`); set `HYPRLAND_WSL_THREADS`
to try another number.

## What this costs

- Everything is rendered on the CPU. An idle desktop uses next to nothing; animations, blur and
  video use CPU in proportion to the screen size. The exception is Ubuntu 26.04, whose older
  Hyprland redraws the screen for every VNC capture and so keeps about three cores busy while a
  viewer is connected.
- The picture goes through VNC, which adds some latency and compression.
- The screen size is fixed when the session starts.
