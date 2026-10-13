# How it works

Why Hyprland does not simply start under WSL2, and what each part of this project does about it.

## The problem

Hyprland's backend library, aquamarine, has three ways to get a screen, and none of them works
under WSL as shipped:

- **A real display device (DRM/KMS).** WSL2 has none. The GPU is exposed as `/dev/dxg`, a
  different interface.
- **A window in another Wayland compositor.** WSLg has one, but it only accepts shared-memory
  buffers and lacks `zwp_linux_dmabuf_v1`, which aquamarine's nested mode requires.
- **Headless**, a screen that exists only in memory. This is the one that fits, but aquamarine's
  headless backend supplies no DRM device, and without one aquamarine cannot create its buffer
  allocator. Hyprland stops with "no allocator available".

What Hyprland needs from that device turns out to be small: a way to allocate buffers, and a
device identity that EGL can be opened on. It does not need mode setting or a display.

## The stack

```
Windows desktop
└─ TigerVNC viewer               a WSLg window, or a viewer running on Windows itself
   └─ wayvnc                     VNC server on 127.0.0.1, attached to Hyprland
Hyprland                         on its headless backend, with the patched aquamarine
└─ your apps
vgem                             virtual DRM device in the WSL kernel
Mesa                             draws on the GPU (Direct3D 12) or on the CPU (llvmpipe)
```

### vgem: a DRM device

The WSL kernel ships the `vgem` module. Loading it creates `/dev/dri/card0` and
`/dev/dri/renderD128`. It has no display outputs and does no rendering. It is there to be the
device Hyprland's allocator and EGL are opened on.

All WSL distros share one kernel, so this part is identical on every distro.

### The patched aquamarine

The patch in [`../patches/`](../patches/) changes three things:

1. **The headless backend opens a DRM device.** `AQ_HEADLESS_DRM_DEVICE` names it; the launcher
   passes vgem's primary node. With that, the allocator can be created.
2. **The allocator stays on that node.** aquamarine would otherwise reopen the device's render
   node, and vgem refuses buffer allocation there ("Permission denied").
3. **The headless backend creates its own output**, sized by `AQ_HEADLESS_MODE`, and buffer
   allocation falls back to the plainest request when a driver refuses the others (see below).

The installer builds a patched copy of the same aquamarine version the distro ships and puts it
in `/opt/hyprland-wsl`. The distro's own package stays as it is. The patch adds no members to
any class, so the library stays compatible with the distro's Hyprland.

### Rendering: GPU or CPU

Mesa has a Direct3D 12 driver that renders through `/dev/dxg`. When it is selected
(`GALLIUM_DRIVER=d3d12`) and EGL is opened on the vgem device, Mesa gives Hyprland a Direct3D 12
renderer, and buffers allocated through that device are Direct3D 12's own. vgem then only lends
its identity. Two consequences:

- Only the plain allocation request works there, which is why the patch adds that fallback.
- Nothing but the Direct3D 12 driver can read those buffers. That is fine here because nothing
  else has to: screen capture reads the picture back into ordinary memory.

Without it, Mesa's software renderer (llvmpipe) draws into vgem's memory on the CPU.

The launcher uses the GPU when `/dev/dxg` and Mesa's `d3d12_dri.so` are present, and falls back
to the CPU if Hyprland does not come up that way. `--software` and `--gpu` choose explicitly. It
prints which one is in use, decided by whether the Direct3D 12 libraries are loaded in Hyprland.

Apps started inside Hyprland inherit the choice, so OpenGL apps draw on the GPU too.

For the CPU case: Mesa's software renderer starts one thread per core, which under WSL costs far
more CPU than it gains. The launcher caps it at 4 (`LP_NUM_THREADS`); `HYPRLAND_WSL_THREADS`
overrides that.

### A private mount namespace

The launcher starts Hyprland in its own mount namespace, a view of the filesystem that only it
and its children have. Two things differ in it:

- The patched aquamarine is mounted over the system's copy. Pointing `LD_LIBRARY_PATH` at it would
  be simpler, but Debian-family packages give the Hyprland binary a file capability, and the
  dynamic loader ignores `LD_LIBRARY_PATH` for such programs.
- `/tmp/.X11-unix` is an empty directory with normal permissions. WSLg mounts its own there with
  permissions that Xwayland setup rejects.

Nothing outside the session sees either change.

### X11 apps

Hyprland starts Xwayland for X11 apps. In GPU mode Xwayland's own GPU drawing (glamor) makes it
exit at start, so the launcher gives Hyprland a small wrapper that runs Xwayland with
`-glamor off`. X11 apps still draw with the GPU themselves.

X servers also listen on a socket name shared by everything in WSL, across distros and mount
namespaces, and X programs try that name first. If Hyprland's Xwayland became display `:0`, the
viewer inside WSL would connect to it instead of to WSLg and open its window inside the session
it is showing. The launcher therefore mounts WSLg's sockets into the private `/tmp/.X11-unix`, so
Xwayland sees `:0` as taken and picks another number.

### wayvnc and the viewer

wayvnc shares Hyprland's screen over VNC, on localhost only, and feeds keyboard and mouse back
into Hyprland as virtual input devices. The launcher lets it send up to 60 frames a second
(`--fps`).

There are two ways to look at it:

- **The WSLg window.** By default the launcher starts TigerVNC's viewer inside WSL. It is an X11
  program, and WSLg shows X11 programs as normal windows on the Windows desktop. Simple, but
  Windows handles the Windows key, Alt+Tab and the like before WSLg gets them.
- **A viewer on Windows.** WSL forwards `127.0.0.1` ports to Windows, so a VNC viewer running
  on Windows can connect to the same server. In full screen, TigerVNC's Windows viewer captures
  the whole keyboard, which makes the Windows key usable as Hyprland's SUPER.
  `windows\hyprland-wsl.ps1` does this: it starts the session with `--no-viewer`, runs the
  viewer, and ends the session when the viewer closes.

## What this costs

- The picture goes through VNC: every frame is read back from the renderer, encoded, sent and
  decoded. That is the largest remaining cost in GPU mode.
- On the CPU, animations, blur and video use CPU in proportion to the screen size.
- The screen size is fixed when the session starts.

## Earlier design

Until October 2026 Hyprland ran nested inside labwc, a second compositor that existed only to
tell aquamarine which DRM device to use, with a larger aquamarine patch for the nested backend
and a render node redirected to the primary node. That version is on the `main` branch.
