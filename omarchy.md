# Omarchy

[Omarchy](https://omarchy.org) is DHH's Linux distribution: Arch Linux with Hyprland, its own
desktop shell, themes, menus and a large set of preinstalled tools. It is meant to be installed
from its ISO onto a whole disk. hyprland-wsl's `tools/omarchy-wsl.sh` installs it into an Arch
WSL instance instead and puts hyprland-wsl on top, so Omarchy's desktop runs on Windows.

Tested on 2026-10-13 with Omarchy 4.0.4, from a clean install, by scripts and screenshots.

## With the launcher

`hyprland-wsl` → **+ New distro** → **Omarchy**. It asks nothing: it picks the next free name
(`omarchy`, `omarchy2`, ...) and starts installing; Omarchy's own setup asks the rest on the
first start, described below.

## One command

In PowerShell, in a clone of hyprland-wsl's [main branch](https://github.com/ItsOverk1ll/hyprland-wsl)
(the launcher keeps one at `%LOCALAPPDATA%\hyprland-wsl\repo`):

```powershell
.\windows\install-omarchy.ps1
```

That creates a new Arch Linux instance called `omarchy`, installs Omarchy into it (several
gigabytes, about ten minutes on an SSD; the instance ends up at roughly 11 GB), and starts it.

The first start is Omarchy's own first-boot setup, the one a machine installed from Omarchy's
USB stick "for another owner" shows when it is switched on: the Omarchy greeting, then your
keyboard layout, your account (user name and password), name and email for git (both
optional), the hostname and the timezone, a summary to confirm, and a progress bar while the
account is created and set up. It runs in the terminal you started the installer from; when it
is done, the desktop starts. Later starts go straight to the desktop.

If the setup is left unfinished, the next start shows it again.

Options:

```powershell
.\windows\install-omarchy.ps1 -Name omarchy2 -Location C:\WSL\omarchy2   # another instance, on a chosen drive
.\windows\install-omarchy.ps1 -NoStart                                   # install only; the setup comes with the first start
.\windows\install-omarchy.ps1 -NoSetup -User me -Password secret         # make the account now, no setup screens
```

By hand, the same thing is:

```powershell
wsl --install archlinux --name omarchy
wsl -d omarchy -u root -- bash /mnt/c/path/to/hyprland-wsl/tools/omarchy-wsl.sh
wsl -t omarchy
.\windows\hyprland-wsl.cmd -Distro omarchy      # runs the setup, then the desktop
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

**Power Off** in Omarchy's system menu shuts the instance down: the session ends, the viewer
closes, and `wsl -l -v` shows the instance as stopped. **Restart** does the same, since WSL does
not start an instance again by itself; start it again with the launcher. **Lock** and the
**screensaver** work as in Omarchy: the screensaver starts after 150 seconds without keyboard
or mouse input, the lock screen after 300 (it asks for the user's password). Both times are
in `~/.config/omarchy/shell.json` under `idle`.

Everything else is in [Omarchy's manual](https://github.com/basecamp/omarchy/tree/dev/manual).

Update with `omarchy update`. Omarchy blocks a direct `pacman -Syu` on purpose.

## What the installer does

The ISO partitions a disk, installs packages from Omarchy's repository, runs Omarchy's system
setup, and either creates the user or, for a machine meant for another owner, leaves that to
a setup on the first boot. The script does the same without the disk and boot parts:

1. Adds Omarchy's package repository and its snapshot of Arch's repositories, and trusts
   Omarchy's signing key.
2. Installs `omarchy-settings`, `omarchy` and the base package list the ISO installs.
3. Runs Omarchy's system setup (`install/config`, login, post-install).
4. Writes the WSL-specific per-user settings into `/etc/skel`, from which the new account's
   home is made.
5. Runs this repository's `install.sh` without a user, and arms the first-start setup:
   `/var/lib/omarchy/provisioning/pending`, as Omarchy's ISO does, and
   `/etc/hyprland-wsl/first-start` (`tools/omarchy-wsl-first-start.sh`).

At the first start, the Windows launcher runs `hyprland-wsl first-start`, which runs Omarchy's
`omarchy-provision-owner` in the terminal (its console-only parts switch themselves off there)
and then does what WSL needs for the new account: the launcher's user, the user's systemd
session without a login, and in `/etc/wsl.conf` the default user, the hostname and the
timezone chosen in the setup (WSL would otherwise take both from Windows at every start).

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
| Power off and reboot are allowed for the user without a password (`/etc/polkit-1/rules.d/50-hyprland-wsl-power.rules`) | The session is not a login session, so the system would ask for a password that nothing can prompt for, and Omarchy's Power Off did nothing. |

Omarchy does not know about any of this. Its own tools for these areas (snapshots, the boot
menu, hardware setup, factory reset, the drive password) will not work and should be left
alone.

## Known gaps

- Tested: start-up on the GPU, the bar, wallpaper, notifications, the terminal, the Omarchy
  menu, the key-binding list, the file manager, Chromium, the screensaver (by script, with the
  timeout shortened), Power Off through the Windows launcher. Not gone through: every menu
  entry, audio, the lock screen, `omarchy update`, theme switching.
- Used by hand by the owner on 2026-10-15: Power Off and the pointer confirmed, started from a
  Windows Terminal command-palette action.
- The first-start setup was tested on a clean install by a script that types the answers
  (`dev-log/scripts/72-drive-first-start.py`): account, hostname and timezone came out as
  chosen, and the desktop started as the new account. Not yet gone through by hand. A
  keyboard layout other than English (US) was not tried.
- The account gets the `wheel` group only. Omarchy's own installer records further groups
  during its system setup (Docker's, for one); add them with `usermod -aG` if needed.
- On first start a "Setup Wi-Fi" notice appears. There is no Wi-Fi to set up; WSL shares
  Windows' connection.
- Bluetooth, Wi-Fi and power settings in the shell have nothing to talk to.
- The pointer has a one-pixel dot at its tip in the Windows viewer, as on the other distros
  (see troubleshooting: the alternatives are a black square or a second, Windows pointer).
