# hyprland-wsl

Run [Hyprland](https://hypr.land) on Arch Linux inside WSL2, in a window on the Windows desktop.

Hyprland does not run under WSL out of the box: WSL has no GPU device node it can use, and WSLg's
compositor lacks the protocols Hyprland needs to run nested. This repository installs a stack that
works around both.

## Requirements

- Windows 11 (or Windows 10 with WSLg) and a current WSL: `wsl --update`
- The official Arch Linux WSL distro: `wsl --install archlinux`

## Install

Inside the Arch distro:

```sh
pacman -Sy --needed git        # after pacman-key --init && pacman-key --populate archlinux on a fresh distro
git clone https://github.com/ItsOverk1ll/hyprland-wsl
cd hyprland-wsl
./install.sh
```

The installer:

- updates the system and installs Hyprland, foot, labwc, wayvnc, TigerVNC and a build toolchain
- picks the user Hyprland runs as (the invoking user, else the first regular user, else a new
  user `hypr`; override with `HYPR_USER=name ./install.sh`)
- builds a patched copy of aquamarine into `/opt/hyprland-wsl` (the system package is untouched)
- installs the `hyprland-wsl` launcher into `/usr/local/bin`
- writes a default Hyprland config if there is none, with ALT as the main modifier and foot as
  the terminal

## Use

```sh
hyprland-wsl                    # 1600x900 window
hyprland-wsl 1920x1080          # another size
hyprland-wsl --no-viewer        # no window; connect a VNC client to 127.0.0.1:5900
hyprland-wsl --port 5901
```

From Windows: `wsl -d archlinux hyprland-wsl`

Closing the viewer window, or Ctrl+C, shuts everything down. Logs are in `/tmp/hyprland-wsl`.

Default keys (main modifier is ALT because Windows keeps the Windows key for itself):

| Keys | Action |
| --- | --- |
| ALT+Q | terminal |
| ALT+C | close window |
| ALT+V | toggle floating |
| ALT+1..0 | switch workspace |
| ALT+M | exit Hyprland |

## How it works

```
vncviewer (WSLg window on the Windows desktop)
   └─ wayvnc
        └─ labwc, headless, software GL
             └─ Hyprland, nested, with patched aquamarine
                  └─ your apps
```

- **vgem** provides a DRM device for buffer allocation. The render node path is pointed at the
  primary node, because dumb buffers cannot be allocated through a render node.
- **labwc** runs headless as the host compositor. It offers `linux-dmabuf` and `xdg_wm_base` v6,
  which Hyprland's nested backend requires and WSLg's compositor does not provide.
- **aquamarine** (Hyprland's backend library) needs two fixes to run under such a host; see
  [`patches/aquamarine-wayland-nested.patch`](patches/aquamarine-wayland-nested.patch).
- **wayvnc** and **vncviewer** get the picture onto the Windows desktop and input back in.

## Limitations

- Rendering is on the CPU (llvmpipe). It idles near zero, but animations and blur cost CPU.
- XWayland apps inside Hyprland do not work.
- The patch is written for aquamarine 0.15.1. After a `pacman -Syu` that updates Hyprland or
  aquamarine, rerun `./install.sh` to rebuild; if the patch no longer applies, the installer says so.
- Keyboard layout is whatever Hyprland is configured with; the Windows layout is not passed through.

## Uninstall

```sh
./uninstall.sh
```

Removes the launcher and the patched library. Packages, the user and `~/.config/hypr` stay.
