# Opens the hyprland-wsl menu (launcher.ps1) with Win+Shift+H, as a small popup terminal.
#
# The popup comes from BetterHotkeys (https://github.com/ItsOverk1ll/BetterHotkeys), which
# this script adds the hotkey to. Without BetterHotkeys it says how to get it; the menu is
# still one command away: "hyprland-wsl" in any terminal. install.ps1 runs this for you.
#
#   .\install-hotkey.ps1             add Win+Shift+H (or point it at this copy again)
#   .\install-hotkey.ps1 -Remove     take it out again
#
# What it changes, in BetterHotkeys' folder (Documents\AutoHotkey): one hotkey line in
# hotkeys.ahk (backed up first), and a two-line hyprland-wsl.ps1 that the popup runs.

param([switch] $Remove)

$ErrorActionPreference = 'Stop'
$ahkDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AutoHotkey'
$hotkeys = Join-Path $ahkDir 'hotkeys.ahk'
$popupScript = Join-Path $ahkDir 'hyprland-wsl.ps1'
$launcher = Join-Path $PSScriptRoot 'launcher.ps1'
$comment = ';; Win + Shift + H | Hyprland on WSL: start a distro (toggle)'
$binding = '#+h:: PopupTerminal("Hyprland on WSL", "hyprland-wsl.ps1", 960, 560)'

# UTF-8 without a byte order mark, the same in Windows PowerShell 5.1 and PowerShell 7.
function Save-Text($path, $text) { [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false)) }

function Restart-Hotkeys {
    # Opening the script starts it again; BetterHotkeys' script replaces its running copy.
    Start-Process explorer.exe "`"$hotkeys`""
}

$text = if (Test-Path $hotkeys) { Get-Content $hotkeys -Raw } else { '' }
$hasBetterHotkeys = $text -match 'PopupTerminal\('

if ($Remove) {
    if ($text -match [regex]::Escape($binding)) {
        Copy-Item $hotkeys "$hotkeys.before-hyprland-wsl" -Force
        # The two lines, and the blank line the install put after them.
        $lines = [Collections.Generic.List[string]](Get-Content $hotkeys)
        $i = $lines.IndexOf($binding)
        if ($i -ge 0 -and $i + 1 -lt $lines.Count -and $lines[$i + 1] -eq '') { $lines.RemoveAt($i + 1) }
        $lines = $lines | Where-Object { $_ -ne $comment -and $_ -ne $binding }
        Save-Text $hotkeys (($lines -join "`r`n") + "`r`n")
        Restart-Hotkeys
    }
    Remove-Item $popupScript -ErrorAction SilentlyContinue
    Write-Host 'Win+Shift+H no longer opens the hyprland-wsl menu.'
    return
}

if (-not $hasBetterHotkeys) {
    Write-Host @"
The Win+Shift+H popup comes from BetterHotkeys, which is not installed. It is recommended:
it also gives you Win+K (a cheatsheet of your hotkeys), web apps and themes. Install it with

    irm https://raw.githubusercontent.com/ItsOverk1ll/BetterHotkeys/main/web-install.ps1 | iex

and run the launcher's install.ps1 again. Without it, open the menu by typing this in any terminal:

    hyprland-wsl
"@
    return
}

# The popup runs a script from BetterHotkeys' folder; this one opens the menu of this copy.
Save-Text $popupScript ("# Popup for Win+Shift+H (hyprland-wsl): the menu of WSL distros. Written by install-hotkey.ps1.`r`n" +
    "& '$launcher'`r`n")

if ($text -match [regex]::Escape($binding)) {
    Write-Host "Win+Shift+H already opens the hyprland-wsl menu; it now uses $launcher."
    return
}
if ($text -match '(?m)^\s*#\+h::') {
    Write-Host "Win+Shift+H is already used for something else in $hotkeys. Change that line, or"
    Write-Host "add this one yourself with other keys (in AutoHotkey, # is Win, + Shift, ^ Ctrl, ! Alt):"
    Write-Host "    $binding"
    return
}

Copy-Item $hotkeys "$hotkeys.before-hyprland-wsl" -Force
# Before PopupTerminal's definition, where BetterHotkeys keeps its other popups; at the end otherwise.
$add = "$comment`r`n$binding`r`n`r`n"
$at = $text.IndexOf("`n; Toggles a small centered terminal")
if ($at -lt 0) { $at = $text.IndexOf("`nPopupTerminal(") }
$text = if ($at -ge 0) { $text.Insert($at + 1, $add) } else { $text.TrimEnd() + "`r`n`r`n" + $add }
Save-Text $hotkeys $text
Restart-Hotkeys
Write-Host 'Win+Shift+H now opens the hyprland-wsl menu (press it again to close it).'
Write-Host "It is listed in the Win+K cheatsheet. hotkeys.ahk was saved as hotkeys.ahk.before-hyprland-wsl first."
