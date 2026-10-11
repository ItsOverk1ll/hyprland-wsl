# Distro notes

What was found on each distro, as tested on 2026-10-11 with WSL 2.5.9 (kernel 6.6.87.2). Versions
are what the distros shipped that day and will move.

| | Arch | CachyOS | Kali rolling | Ubuntu 26.04 | Linux Mint 22.3 |
| --- | --- | --- | --- | --- | --- |
| Get it with | `wsl --install archlinux` | Docker image | `wsl --install kali-linux` | `wsl --install Ubuntu-26.04` | Docker image |
| Package manager | pacman | pacman | apt | apt | apt |
| Hyprland | 0.56.2 | 0.56.2 | 0.56.2 | 0.53.3 | 0.56.2, from a PPA |
| aquamarine | 0.15.1 | 0.15.1 | 0.14.0 | 0.10.0 | 0.15.1, from a PPA |
| labwc (host) | 0.20.2 | 0.20.2 | 0.20.2 | 0.9.3 | 0.7.1 |
| Config format | Lua | Lua | Lua | `hyprland.conf` | Lua |
| Install time on an SSD | under 1 min | under 1 min | 1 to 2 min | under 1 min | under 1 min |

## Arch Linux

- A fresh image needs its pacman keyring initialised before anything can be installed. The
  installer does it.
- The installer runs a full `pacman -Syu`. Arch does not support installing packages onto a
  system that is only partly up to date.
- Being a rolling release, Hyprland and aquamarine change often. After an update that touches
  either, the launcher asks for `./install.sh` to be rerun.

## CachyOS

- No WSL image; import the `cachyos/cachyos` Docker image as described in the README.
- Behaves like Arch. Hyprland comes from Arch's `extra` repository, Mesa from CachyOS's own.
- The image does not enable systemd. Nothing here needs it.

## Kali Linux

- Hyprland is in Kali's own repositories, at the same version as Arch.
- The package gives `/usr/bin/Hyprland` the file capability `cap_sys_nice`. That is why the
  launcher mounts the patched library instead of using `LD_LIBRARY_PATH`; see
  [how-it-works.md](how-it-works.md).
- A second small `Hyprland` process is libseat's seat helper. Normal.

## Ubuntu 26.04

- Hyprland 0.53.3, which is noticeably older: it uses the `hyprland.conf` format, not Lua, and
  logs nothing unless asked to (see [troubleshooting.md](troubleshooting.md)).
- aquamarine 0.10.0 needs its own patch file, which has one more fix than the newer one.
- Its labwc refuses to start over WSLg's `/tmp/.X11-unix`; the launcher's mount namespace takes
  care of that.

## Linux Mint 22.3

- No WSL image. The `linuxmintd/mint22.3-amd64` Docker image can be imported (README), but it is
  Mint's package build environment: it identifies as Ubuntu until Mint's base packages are
  installed, and it has no Cinnamon desktop.
- Mint 22.x is built on Ubuntu 24.04, which has no Hyprland package. The installer offers the
  third-party PPA `ppa:cppiber/hyprland` and asks first.
- The PPA also upgrades some system libraries (libinput, libxkbcommon, libdisplay-info).
- Its labwc (0.7.1) is the oldest host tested and needs the patch's protocol-version fix.
- The `mint23-amd64` image is a pre-release without a package repository. Do not use it yet.

## Not covered yet

- **Ubuntu 24.04**: expected to work the same way as Mint 22.3, untested.
- **Debian**: not looked at.
- **Fedora, openSUSE**: need their own branch in the installer; not started.
