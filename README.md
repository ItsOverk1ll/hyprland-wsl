# hyprland-wsl: other ways to open the menu

[hyprland-wsl](https://github.com/ItsOverk1ll/hyprland-wsl) comes with a menu for Windows that
starts, creates and removes your Hyprland distros. Its installer gives you two ways to open it,
and they need nothing else:

- type `hyprland-wsl` in any terminal (PowerShell, cmd, Windows Terminal)
- the **Hyprland on WSL** entry in the Start menu

This branch holds optional extras on top of that. Nothing in hyprland-wsl depends on them.

## Win+Shift+H, with BetterHotkeys

[BetterHotkeys](https://github.com/ItsOverk1ll/BetterHotkeys) is a small set of Windows hotkeys
made with AutoHotkey: Win+K shows a cheatsheet of your hotkeys, Win+Shift+Space opens web apps,
Win+Shift+T switches themes. Its popups are small terminals in the middle of the screen, and
hyprland-wsl's menu fits in the same way: **Win+Shift+H** opens it, pressing it again closes
it, and starting a distro closes it too. The menu also takes BetterHotkeys' current theme.

1. Install hyprland-wsl (see its [README](https://github.com/ItsOverk1ll/hyprland-wsl)).
2. Install BetterHotkeys:

   ```powershell
   irm https://raw.githubusercontent.com/ItsOverk1ll/BetterHotkeys/main/web-install.ps1 | iex
   ```

3. Add the hotkey:

   ```powershell
   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/Launcher/install-hotkey.ps1 | iex
   ```

It adds one line to BetterHotkeys' `Documents\AutoHotkey\hotkeys.ahk` (saving the file as
`hotkeys.ahk.before-hyprland-wsl` first) and a two-line `hyprland-wsl.ps1` next to it that opens
the menu. The hotkey shows up in the Win+K cheatsheet. If Win+Shift+H is already taken, the
script changes nothing and prints the line to add with other keys.

From a clone of this branch, `-Menu` points the hotkey at a clone of hyprland-wsl of your own,
and `-Remove` takes the hotkey out again:

```powershell
.\install-hotkey.ps1 -Menu C:\path\to\hyprland-wsl\windows\launcher.ps1
.\install-hotkey.ps1 -Remove
```

## Any other hotkey tool

Any tool that can run a program on a key works. The program is:

```
wt.exe -w new pwsh -NoLogo -NoProfile -Command hyprland-wsl
```
