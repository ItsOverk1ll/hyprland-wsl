# Distro notes

What was found on each distro with WSL 2.5.9 (kernel 6.6.87.2). Versions are what the distros
shipped on 2026-10-11 and will move.

The current stack (Hyprland on its headless backend, GPU rendering) was tested on 2026-10-13
with clean installs on **Arch, CachyOS, Kali and Mint**, and tried on **Ubuntu 26.04** from a
side-by-side build. Mesa on that day: 26.2.4 on Arch and CachyOS, 26.1.6 on Kali, 26.0.8 on
Ubuntu, 25.2.8 on Mint.

| | Arch | CachyOS | Kali rolling | Ubuntu 26.04 | Linux Mint 22.3 |
| --- | --- | --- | --- | --- | --- |
| Get it with | `wsl --install archlinux` | Docker image | `wsl --install kali-linux` | `wsl --install Ubuntu-26.04` | Docker image |
| Package manager | pacman | pacman | apt | apt | apt |
| Hyprland | 0.56.2 | 0.56.2 | 0.56.2 | 0.53.3 | 0.56.2, from a PPA |
| aquamarine | 0.15.1 | 0.15.1 | 0.14.0 | 0.10.0 | 0.15.1, from a PPA |
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
- aquamarine 0.10.0 needs its own patch file (`headless-drm-0.10.patch`).
- Works on the GPU and on the CPU. On the CPU it is slow to react (about 130 ms from key to
  screen, against 8 ms on the GPU).
- The monitor reports 0.06 Hz. aquamarine 0.10 gives the headless output a refresh rate of 60
  where later versions give 60000 (the unit is mHz). Not looked into further.

## Linux Mint 22.3

- No WSL image. The `linuxmintd/mint22.3-amd64` Docker image can be imported (README), but it is
  Mint's package build environment: it identifies as Ubuntu until Mint's base packages are
  installed, and it has no Cinnamon desktop.
- The image's only regular user is called `ubuntu`, and the installer picks it, so the terminal
  prompt reads `ubuntu@...` although the system is Mint. To avoid the confusion, install with
  another user: `HYPR_USER=mint ./install.sh` (the user is created if missing).
  `cat /etc/os-release` tells you which distro a session really is.
- Mint 22.x is built on Ubuntu 24.04, which has no Hyprland package. The installer offers the
  third-party PPA `ppa:cppiber/hyprland` and asks first.
- The PPA also upgrades some system libraries (libinput, libxkbcommon, libdisplay-info).
- The `mint23-amd64` image is a pre-release without a package repository. Do not use it yet.
- **CPU rendering only.** In GPU mode Hyprland runs and takes input, but the picture never
  reaches the viewer: capture requests through the `wlr-screencopy` protocol, which Mint's
  wayvnc (0.7.2) and grim use, are never answered. Kali's newer clients use
  `ext-image-copy-capture` and Ubuntu 26.04 captures fine through `wlr-screencopy` with Mesa 26,
  so Mint's Mesa 25.2.8 is the suspect; that was not proven. The launcher uses the CPU when
  Mesa is older than 26.
- Its Xwayland (23.2.6) has no `-glamor off`; the launcher uses `-shm` there.
- A root filesystem made with an older `tools/merge-layers.sh` has `/` at mode 700, and then
  nothing works for a regular user ("unable to execute /usr/bin/env: Permission denied"). The
  installer now sets it to 755 and says so.

## Not covered yet

- **Ubuntu 24.04**: expected to work the same way as Mint 22.3, untested.
- **Debian**: not looked at.
- **Fedora, openSUSE**: need their own branch in the installer; not started.
