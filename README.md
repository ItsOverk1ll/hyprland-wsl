# hyprland-wsl

Run [Hyprland](https://hypr.land) inside WSL2, in a window on the Windows desktop.

Hyprland does not run under WSL out of the box: WSL has no GPU device node it can use, and WSLg's
compositor lacks the protocols Hyprland needs to run nested. This repository installs a stack that
works around both.

The aim is to support all major Linux distributions under WSL2.

## Supported distros

Tested on 2026-10-11 with WSL 2.5.9:

| Distro | Hyprland | Comes from | Notes |
| --- | --- | --- | --- |
| Arch Linux | 0.56.2 | distro repos | |
| CachyOS | 0.56.2 | distro repos | no WSL image, see [Distros without a WSL image](#distros-without-a-wsl-image) |
| Kali Linux (rolling) | 0.56.2 | distro repos | |
| Ubuntu 26.04 | 0.53.3 | distro repos | older Hyprland with the `hyprland.conf` config format |
| Linux Mint 22.3 | 0.56.2 | third-party PPA | no WSL image; Mint has no Hyprland package of its own |

Other Arch-based and Debian/Ubuntu-based distros may work, since the installer goes by package
family, but only the ones above were tried. Ubuntu 24.04 should behave like Mint 22.3 (same base)
and is untested. Fedora and openSUSE are not supported yet.

## Requirements

- Windows 11 (or Windows 10 with WSLg) and a current WSL: `wsl --update`
- One of the distros above, for example `wsl --install archlinux`, `wsl --install kali-linux` or
  `wsl --install Ubuntu-26.04`

## Install

Inside the distro:

```sh
git clone https://github.com/ItsOverk1ll/hyprland-wsl
cd hyprland-wsl
./install.sh
```

If `git` is missing: `pacman -Sy --needed git` on Arch-based distros (on a fresh Arch image run
`pacman-key --init && pacman-key --populate` first), `apt install git` on the others.

The installer:

- installs Hyprland, foot, labwc, wayvnc, TigerVNC's viewer and a build toolchain. On Arch-based
  distros this is a full system upgrade (`pacman -Syu`), because Arch does not support installing
  onto a partly updated system.
- picks the user Hyprland runs as (the invoking user, else the first regular user, else a new
  user `hypr`; override with `HYPR_USER=name ./install.sh`)
- builds a patched copy of aquamarine, in the version the distro ships, into `/opt/hyprland-wsl`
  (the system package is untouched)
- installs the `hyprland-wsl` launcher into `/usr/local/bin`
- writes a default Hyprland config if there is none, with ALT as the main modifier and foot as
  the terminal

### The PPA on Ubuntu 24.04-based distros

Linux Mint 22.x and Ubuntu 24.04 have no `hyprland` package. The installer then offers to add the
third-party PPA [`ppa:cppiber/hyprland`](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland)
and asks first. That PPA is not part of the distro and is not run or checked by this project; it
also replaces a few system libraries (libinput, libxkbcommon and others) with newer builds. To
allow it without the question: `HYPRLAND_PPA=1 ./install.sh`.

## Use

```sh
hyprland-wsl                    # 1600x900 window
hyprland-wsl 1920x1080          # another size
hyprland-wsl --no-viewer        # no window; connect a VNC client to 127.0.0.1:5900
hyprland-wsl --port 5901
```

From Windows: `wsl -d <distro> hyprland-wsl`

Closing the viewer window, or Ctrl+C, shuts everything down. Logs are in `/tmp/hyprland-wsl`.

Default keys (main modifier is ALT because Windows keeps the Windows key for itself):

| Keys | Action |
| --- | --- |
| ALT+Q | terminal |
| ALT+C | close window |
| ALT+V | toggle floating |
| ALT+1..0 | switch workspace |
| ALT+M | exit Hyprland |

## Distros without a WSL image

CachyOS and Linux Mint are not in `wsl --list --online`. Both publish Docker images, and a Docker
image's filesystem can be imported into WSL without Docker. `tools/` has two helpers for that.

**CachyOS** (one layer, imports directly), from PowerShell in a clone of this repo:

```powershell
.\tools\Get-DockerRootfs.ps1 -Image cachyos/cachyos -OutDir C:\WSL\images\cachyos
wsl --import CachyOS C:\WSL\CachyOS C:\WSL\images\cachyos\layer01.tar.gz
```

**Linux Mint 22.3** (several layers, which have to be flattened inside any existing WSL distro):

```powershell
.\tools\Get-DockerRootfs.ps1 -Image linuxmintd/mint22.3-amd64 -OutDir C:\WSL\images\mint
wsl -u root -- bash tools/merge-layers.sh /mnt/c/WSL/images/mint /mnt/c/WSL/images/mint/rootfs.tar.gz
wsl --import Mint C:\WSL\Mint C:\WSL\images\mint\rootfs.tar.gz
```

Mint's image is its package build environment and still identifies as Ubuntu. Installing Mint's
base packages turns it into a system that identifies as Linux Mint (run inside the new distro):

```sh
apt-get update
apt-get install -y --allow-downgrades base-files=$(apt-cache madison base-files | awk '/mint/ {print $3; exit}') \
    mintsystem mintsources mint-mirrors
```

This gives Mint's package base, not the Cinnamon desktop of an installed Mint. The
`mint23-amd64` image on Docker Hub is a pre-release whose package repository does not exist yet;
use 22.3.

Put the distro on an SSD. On a hard disk, package installation inside WSL is many times slower.

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
- **labwc** runs headless as the host compositor. It offers `linux-dmabuf`, which Hyprland's
  nested backend requires and WSLg's compositor does not provide.
- **aquamarine** (Hyprland's backend library) needs fixes to run under such a host; see
  [`patches/`](patches/). There is one patch per layout of the patched file, and the installer
  uses the one that applies to the distro's aquamarine version.
- The compositors run in a **private mount namespace**. In it the patched aquamarine is mounted
  over the system one (an `LD_LIBRARY_PATH` is ignored on distros that give Hyprland a file
  capability), and `/tmp/.X11-unix` is a fresh directory (WSLg's one makes Xwayland setup fail).
- **wayvnc** and TigerVNC's viewer get the picture onto the Windows desktop and input back in.

## Limitations

- Rendering is on the CPU (llvmpipe). It idles near zero, but animations and blur cost CPU.
- XWayland apps inside Hyprland are untested.
- The patched aquamarine is tied to the distro's aquamarine version. After a system update that
  changes Hyprland or aquamarine, the launcher says so; rerun `./install.sh` to rebuild. Patches
  exist for aquamarine 0.10.0, 0.14.0 and 0.15.1; for other versions the installer reports
  whether one applies.
- Keyboard layout is whatever Hyprland is configured with; the Windows layout is not passed through.

## Uninstall

```sh
./uninstall.sh
```

Removes the launcher and the patched library. Packages, the user and `~/.config/hypr` stay.
