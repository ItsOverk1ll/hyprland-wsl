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
| Omarchy 4 (in progress) | 0.56.2 | GPU | [omarchy.md](omarchy.md) |
| Others | | | [other-distros.md](other-distros.md) |

Versions as tested on 2026-10-13 to 2026-10-15 with WSL 2.5.9; rolling distros move on.

## Three ways to install

Every guide has all three. They end in the same place.

1. **The menu** (easiest). Install hyprland-wsl once with its one-line installer (see
   [Getting started](https://github.com/ItsOverk1ll/hyprland-wsl/blob/main/docs/getting-started.md)):

   ```powershell
   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/main/windows/bootstrap.ps1 | iex
   ```

   Then open **Hyprland on WSL** from the Start menu (or type `hyprland-wsl` in a terminal),
   choose **+ New distro**, pick the distro and fill in the form: name, folder, user, password,
   hostname, main key. A few minutes later it starts.
2. **One command**, from the copy the installer downloaded:
   `& "$env:LOCALAPPDATA\hyprland-wsl\repo\windows\new-distro.ps1" -Distro arch -Name arch -User me`
   (or `.\windows\new-distro.ps1` in a clone). It asks for the password. The menu runs exactly this.
3. **By hand**, step by step, with a clone of hyprland-wsl's
   [main branch](https://github.com/ItsOverk1ll/hyprland-wsl). Nothing else needed.

Ways 1 and 2 make the account (with sudo), set the hostname and the default user, install
Hyprland, set the main key, and skip the distro's own first-run "create a user" prompt.

## Before you start

- Windows 11 or Windows 10 with WSL 2. The one-line installer sets WSL up if it is missing; by
  hand, `wsl --install` once, and `wsl --update` to bring it up to date.
- Put distros on an SSD. On a hard disk, installing packages inside WSL is many times slower.
  The menu puts them in `C:\WSL\<name>`, or under the folder in the `HYPRLAND_WSL_DISTROS`
  environment variable.
- For the by-hand way, git on Windows (`winget install Git.Git`) and a clone:
  `git clone https://github.com/ItsOverk1ll/hyprland-wsl`.

## After installing

Start a distro full screen, with the whole keyboard (including the Windows key) going to
Hyprland, from its Start menu entry, the menu, or `hyprland-wsl -Distro NAME`. **Ctrl+Alt+Enter** leaves
full screen. Closing the viewer ends the session. More in hyprland-wsl's
[README](https://github.com/ItsOverk1ll/hyprland-wsl#use).

## Removing a distro

In the menu, select it, press **Ctrl+D** and type its name. That removes the distro and
its disk, its folder if empty, its Start menu entry, its Windows Terminal profiles and the Store
app it came from. Without the menu: `wsl --unregister NAME` removes the distro and its disk.

This branch holds only these guides. hyprland-wsl itself, the menu included, is on
[main](https://github.com/ItsOverk1ll/hyprland-wsl); optional extras such as a Win+Shift+H popup
are on [Launcher](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Launcher).
