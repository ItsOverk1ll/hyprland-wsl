# Omarchy

[Omarchy](https://omarchy.org) is DHH's Linux distribution: Arch Linux with Hyprland, its own
desktop shell, themes, menus and a large set of preinstalled tools. It is meant to be installed
from its ISO onto a whole disk. `tools/omarchy-wsl.sh` installs it into an Arch WSL instance
instead and puts hyprland-wsl on top, so Omarchy's desktop runs in a window on Windows.

Tested on 2026-10-13 with Omarchy 4.0.4, from a clean install, by scripts and screenshots.

## Install

In PowerShell, in a clone of this repository:

```powershell
.\windows\install-omarchy.ps1
```

That creates a new Arch Linux instance called `omarchy`, installs Omarchy into it, restarts
it once part way through, and finishes. It downloads several gigabytes and takes about ten
minutes on an SSD; the instance ends up at roughly 11 GB.

It creates a user `omarchy` with the password `omarchy` (the lock screen and `sudo` ask for
it). To choose the names:

```powershell
.\windows\install-omarchy.ps1 -Name omarchy -User me -Password secret -Location C:\WSL\omarchy
```

By hand, the same thing is:

```powershell
wsl --install archlinux --name omarchy
wsl -d omarchy -u root -- bash /mnt/c/path/to/hyprland-wsl/tools/omarchy-wsl.sh
wsl -t omarchy          # when the script asks for a restart
wsl -d omarchy -u root -- bash /mnt/c/path/to/hyprland-wsl/tools/omarchy-wsl.sh
```

Use a new instance. The script turns the instance into Omarchy; it is not meant for an Arch
install you already use.

## Use

Omarchy's key bindings are built on the Windows key (SUPER). Windows keeps that key for itself
unless a full-screen viewer captures the keyboard, so start it with the Windows-side launcher:

```powershell
.\windows\hyprland-wsl.cmd -Distro omarchy
```

| Keys | Action |
| --- | --- |
| Super+Return | terminal |
| Super+Space | the Omarchy menu |
| Super+K | list of key bindings |
| Ctrl+Alt+Enter | leave or enter full screen (the viewer's key, not Omarchy's) |

Everything else is in [Omarchy's manual](https://github.com/basecamp/omarchy/tree/dev/manual).

Update with `omarchy update`. Omarchy blocks a direct `pacman -Syu` on purpose.

## What the script does

The ISO partitions a disk, installs packages from Omarchy's repository, then runs Omarchy's
system setup and per-user setup. The script does the last three:

1. Adds Omarchy's package repository and its snapshot of Arch's repositories, and trusts
   Omarchy's signing key.
2. Installs `omarchy-settings`, creates the user, installs `omarchy` and the base package list
   the ISO installs.
3. Runs Omarchy's system setup (`install/config`, login, post-install) and its per-user setup
   (`omarchy-provision-user`).
4. Runs this repository's `install.sh` for the user.

## What is different from a real Omarchy

| Left out or changed | Why |
| --- | --- |
| Omarchy's kernel, bootloader (Limine), boot splash, disk encryption | WSL boots Microsoft's kernel from Windows; there is no boot chain to manage. |
| Snapshots (snapper) | They need a btrfs root; a WSL instance is ext4. Omarchy's config is written, no snapshot is ever made. |
| The hardware steps: laptop fixes, NVIDIA and Intel drivers, Wi-Fi, Bluetooth | There is no such hardware in WSL. The GPU is reached through Mesa's Direct3D 12 driver instead. |
| The login screen (SDDM) is disabled | `hyprland-wsl` starts the session. The user's systemd session is kept running ("linger") so that Omarchy's shell and app launching work without a login. |
| NetworkManager, systemd-resolved and the firewall (ufw) are disabled | WSL does networking and name resolution itself, and a firewall inside the instance would sit between Windows and the session. The network icon in the bar therefore shows no connection although there is one. |
| Screen scale is set to 1 | Omarchy assumes a high-density laptop panel and starts at 2. |
| Apps are started as services of the user's systemd session (`UWSM_APP_UNIT_TYPE=service` in `~/.config/environment.d/`) | Omarchy starts apps through uwsm, which normally moves each new process into the session. That move is refused when Hyprland was not started from inside the session, and then nothing opens. |
| Chromium runs with `--disable-gpu` (`~/.config/chromium-flags.conf`) | It asks the GPU driver for a kind of buffer Mesa's Direct3D 12 driver does not hand out, and exits. Pages are drawn on the CPU; Hyprland still composes on the GPU. |
| The file index (`locate`) skips `/mnt` | Otherwise it would index every Windows drive. |

Omarchy does not know about any of this. Its own tools for these areas (snapshots, the boot
menu, hardware setup, factory reset, the drive password) will not work and should be left
alone.

## Known gaps

- Tested: start-up on the GPU, the bar, wallpaper, notifications, the terminal, the Omarchy
  menu, the key-binding list, the file manager, Chromium. Not gone through: every menu entry,
  audio, the lock screen, the screensaver, `omarchy update`, theme switching.
- Nobody has used it by hand yet.
- On first start a "Setup Wi-Fi" notice appears. There is no Wi-Fi to set up; WSL shares
  Windows' connection.
- Bluetooth, Wi-Fi and power settings in the shell have nothing to talk to.
- The pointer has a small dot at its tip in the Windows viewer, as on the other distros.
