# Operating systems for hyprland-wsl

Guides for installing each Linux distribution in WSL with
[hyprland-wsl](https://github.com/ItsOverk1ll/hyprland-wsl), so Hyprland runs on Windows, from
nothing to a running desktop. Pick one:

| Distro | Hyprland | Renders on | Guide |
| --- | --- | --- | --- |
| Arch Linux | 0.56.2 | GPU | [arch.md](arch.md) |
| CachyOS | 0.56.2 | GPU | [cachyos.md](cachyos.md) |
| Kali Linux (rolling) | 0.56.2 | GPU | [kali.md](kali.md) |
| Ubuntu 26.04 | 0.53.3 | GPU, less smooth | [ubuntu.md](ubuntu.md) |
| Linux Mint 22.3 | 0.56.2, from a PPA | GPU with a newer Mesa from a PPA | [mint.md](mint.md) |
| Omarchy 4 | 0.56.2 | GPU | [omarchy.md](omarchy.md) |
| Others | | | [other-distros.md](other-distros.md) |

Versions as tested on 2026-10-13 to 2026-10-15 with WSL 2.5.9; rolling distros move on.

## Three ways to install

Every guide has all three. They end in the same place.

1. **The launcher menu** (easiest). Install the
   [launcher](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Launcher) once, type
   `hyprland-wsl` in a terminal (or press Win+Shift+H), choose **+ New distro**, pick the distro
   and fill in the form: name, folder, user, password, hostname, main key. A couple of minutes
   later it starts.
2. **One command**, from the launcher's folder:
   `& "$env:LOCALAPPDATA\hyprland-wsl\launcher\new-distro.ps1" -Distro arch -Name arch -User me`.
   It asks for the password. The menu runs exactly this.
3. **By hand**, step by step, with a clone of hyprland-wsl's
   [main branch](https://github.com/ItsOverk1ll/hyprland-wsl). Nothing else needed.

Ways 1 and 2 make the account (with sudo), set the hostname and the default user, install
Hyprland, set the main key, and skip the distro's own first-run "create a user" prompt.

## Before you start

- Windows 11 with WSL 2: `wsl --install` once if you have never used WSL, `wsl --update` to bring
  it up to date.
- Put distros on an SSD. On a hard disk, installing packages inside WSL is many times slower.
  The launcher puts them in `C:\WSL\<name>`, or under the folder in the `HYPRLAND_WSL_DISTROS`
  environment variable.
- For the by-hand way, git on Windows (`winget install Git.Git`) and a clone:
  `git clone https://github.com/ItsOverk1ll/hyprland-wsl`.

## After installing

Start a distro full screen, with the whole keyboard (including the Windows key) going to
Hyprland, from the launcher menu or with `hyprland-wsl -Distro NAME`. **Ctrl+Alt+Enter** leaves
full screen. Closing the viewer ends the session. More in hyprland-wsl's
[README](https://github.com/ItsOverk1ll/hyprland-wsl#use).

## Removing a distro

In the launcher menu, select it, press **Ctrl+D** and type its name. That removes the distro and
its disk, its folder if empty, its Windows Terminal profiles and the Store app it came from.
Without the launcher: `wsl --unregister NAME` removes the distro and its disk.

This branch holds only these guides. hyprland-wsl itself is on
[main](https://github.com/ItsOverk1ll/hyprland-wsl), the menu on
[Launcher](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Launcher).
