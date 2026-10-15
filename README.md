# hyprland-wsl launcher

A menu for [hyprland-wsl](https://github.com/ItsOverk1ll/hyprland-wsl) in the Windows terminal:
it lists your WSL distros, shows which ones have Hyprland and whether they render on the GPU,
starts them full screen, installs new ones with Hyprland in a couple of minutes, and removes
old ones completely. Open it by typing `hyprland-wsl` in any terminal, or with **Win+Shift+H**.

## Install

From PowerShell:

```powershell
irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/Launcher/install.ps1 | iex
```

It downloads the launcher and hyprland-wsl itself (the
[main branch](https://github.com/ItsOverk1ll/hyprland-wsl)) into
`%LOCALAPPDATA%\hyprland-wsl`, installs PowerShell 7 and fzf with winget if they are missing,
adds the `hyprland-wsl` command, and sets up Win+Shift+H if BetterHotkeys is installed (below).
Running it again updates everything. You can [read the script](install.ps1) first.

Needs Windows 11 with WSL 2 (`wsl --install` once, if you have never used WSL).

Already have a clone of hyprland-wsl? Use it instead of a downloaded copy, from a clone of this
branch:

```powershell
git clone -b Launcher https://github.com/ItsOverk1ll/hyprland-wsl hyprland-wsl-launcher
.\hyprland-wsl-launcher\install.ps1 -Repo C:\path\to\hyprland-wsl
```

## Opening it

### Win+Shift+H, with BetterHotkeys (recommended)

[BetterHotkeys](https://github.com/ItsOverk1ll/BetterHotkeys) is a small set of Windows hotkeys
made with AutoHotkey: Win+K shows a cheatsheet of your hotkeys, Win+Shift+Space opens web apps,
Win+Shift+T switches themes. Its popups are small terminals in the middle of the screen, and the
menu fits in the same way: **Win+Shift+H** opens it, pressing it again closes it, and starting a
distro closes it too. The menu also takes BetterHotkeys' current theme.

Install BetterHotkeys first, then this launcher (or run the launcher's installer again):

```powershell
irm https://raw.githubusercontent.com/ItsOverk1ll/BetterHotkeys/main/web-install.ps1 | iex
```

The installer adds one line to `Documents\AutoHotkey\hotkeys.ahk` (saved as
`hotkeys.ahk.before-hyprland-wsl` first) and shows the hotkey in the Win+K cheatsheet. If
Win+Shift+H is already taken, it changes nothing and prints the line to add with other keys.
`install.ps1 -NoHotkey` skips this step.

### The `hyprland-wsl` command

Type `hyprland-wsl` in any terminal opened after installing (PowerShell, cmd, Windows Terminal).
No extra software. With options it starts a distro directly instead of opening the menu:

```powershell
hyprland-wsl -Distro arch              # full screen, keyboard captured
hyprland-wsl -Distro arch -Windowed    # in a window
```

The options are hyprland-wsl's own, described in its
[README](https://github.com/ItsOverk1ll/hyprland-wsl#full-screen-with-the-whole-keyboard-including-the-windows-key).
To bind the menu to a key without BetterHotkeys, any hotkey tool that runs a program works:
`wt.exe -w new pwsh -NoLogo -NoProfile -Command hyprland-wsl`.

## Using it

| Key | Action |
| --- | --- |
| Enter | start full screen (on a distro without hyprland-wsl: offer to install it) |
| Ctrl+W | start in a window |
| Ctrl+T | stop the distro |
| Ctrl+D | remove the distro completely (asks you to type its name first) |
| Ctrl+R | look at every distro again |
| Esc | close |

**+ New distro**, the top row, installs a new one: Arch Linux, CachyOS, Kali Linux, Ubuntu 26.04
or Linux Mint 22.3, then a short form for the name, folder, user, password, hostname, main key
(SUPER or ALT), whether it becomes WSL's default and whether to start it. The user gets sudo with
that password. **Omarchy** asks nothing here; its own setup screens open on its first start.
Step-by-step guides for each distro, with or without the launcher, are on the
[Operating-Systems branch](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems).

**Removing** a distro deletes its disk (`wsl --unregister`), its folder when nothing else is in
it, its Windows Terminal profiles (the one WSL made and any you made that start it) and the
Microsoft Store app it came from, if any. The menu lists all of it before you confirm, and backs
up Terminal's settings to `%LOCALAPPDATA%\hyprland-wsl\backups` first.

New distros go to `C:\WSL\<name>`, or under the folder in the `HYPRLAND_WSL_DISTROS` environment
variable, for example a separate drive:

```powershell
[Environment]::SetEnvironmentVariable('HYPRLAND_WSL_DISTROS', 'D:\WSL', 'User')
```

The menu looks at each distro once, by starting it, and remembers the answer in
`%LOCALAPPDATA%\hyprland-wsl\distros.json`.

## Without the menu

The scripts behind it work on their own, from `%LOCALAPPDATA%\hyprland-wsl\launcher`:

```powershell
.\new-distro.ps1 -Distro arch -Name myarch -User me     # asks for the password
.\remove-distro.ps1 -Name myarch
.\install-hotkey.ps1 -Remove
```

## Uninstall

```powershell
irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/Launcher/uninstall.ps1 | iex
```

It removes Win+Shift+H, the command and the launcher's files. Your distros stay, and so does a
clone you gave the installer with `-Repo`.

## What is in this branch

This branch holds only the launcher; hyprland-wsl itself is on
[main](https://github.com/ItsOverk1ll/hyprland-wsl), and the distro guides on
[Operating-Systems](https://github.com/ItsOverk1ll/hyprland-wsl/tree/Operating-Systems).

| File | |
| --- | --- |
| `install.ps1`, `uninstall.ps1` | install and remove the launcher |
| `src/launcher.ps1` | the menu |
| `src/new-distro.ps1`, `src/new-distro-setup.sh` | create a distro; the second part runs inside it |
| `src/remove-distro.ps1` | remove a distro and what belongs to it |
| `src/install-hotkey.ps1` | add or remove Win+Shift+H in BetterHotkeys |
| `src/distro-info.sh` | what the menu asks each distro |
| `src/common.ps1` | shared: where hyprland-wsl is, where distros go |
