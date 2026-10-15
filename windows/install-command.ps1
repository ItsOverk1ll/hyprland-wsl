# Makes "hyprland-wsl" a command in Windows terminals (PowerShell, cmd, Windows Terminal), and
# adds "Hyprland on WSL" to the Start menu (and, with -Desktop, the desktop), which opens the menu:
#
#   hyprland-wsl                          the menu of your WSL distros (launcher.ps1)
#   hyprland-wsl -Distro NAME [...]       start that distro's Hyprland (hyprland-wsl.ps1)
#
# It writes a small hyprland-wsl.cmd into %LOCALAPPDATA%\hyprland-wsl\bin, pointing at this
# checkout, and adds that folder to your user PATH. Terminals opened afterwards know the
# command. bootstrap.ps1 and install-omarchy.ps1 run this for you; running it again is harmless.
#
#   .\install-command.ps1             add the command and the Start menu entry
#   .\install-command.ps1 -Desktop    also a desktop shortcut
#   .\install-command.ps1 -Remove     remove the command and every hyprland-wsl shortcut
#
# Works in Windows PowerShell 5.1. The menu itself needs PowerShell 7.

param([switch] $Remove, [switch] $Desktop)

$ErrorActionPreference = 'Stop'
$bin = Join-Path $env:LOCALAPPDATA 'hyprland-wsl\bin'
$shim = Join-Path $bin 'hyprland-wsl.cmd'
$target = Join-Path $PSScriptRoot 'hyprland-wsl.ps1'
$menu = Join-Path $PSScriptRoot 'launcher.ps1'
. (Join-Path $PSScriptRoot 'common.ps1')

# The user PATH, read without expanding %VARIABLES% so they survive being written back.
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$path = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$entries = @($path -split ';' | Where-Object { $_ })
$listed = $entries | Where-Object { $_.TrimEnd('\') -ieq $bin }

function Save-UserPath($entries) {
    $key.SetValue('Path', ($entries -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    # Tells Explorer and new terminals that the environment changed (the variable itself is unused).
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', '1', 'User')
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', $null, 'User')
}

if ($Remove) {
    if ($listed) { Save-UserPath @($entries | Where-Object { $_.TrimEnd('\') -ine $bin }) }
    Remove-Item $shim -ErrorAction SilentlyContinue
    # The menu's shortcut and the ones for distros the menu made.
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in $startMenu, [Environment]::GetFolderPath('Desktop')) {
        Get-ChildItem $dir -Filter *.lnk -ErrorAction SilentlyContinue |
            Where-Object { $shell.CreateShortcut($_.FullName).Description -like 'hyprland-wsl*' } |
            Remove-Item
    }
    Write-Host 'Removed the hyprland-wsl command and its shortcuts.'
    return
}

New-Item -ItemType Directory -Force $bin | Out-Null
# PowerShell 7 when it is there (the menu needs it), Windows PowerShell otherwise.
$cmd = @(
    '@echo off'
    'rem hyprland-wsl on Windows: without arguments the menu of WSL distros, with them a session'
    'rem (hyprland-wsl -Distro NAME). Written by install-command.ps1 in the hyprland-wsl checkout.'
    'setlocal'
    'set "PS=powershell"'
    'where pwsh >nul 2>nul && set "PS=pwsh"'
    'if "%~1"=="" goto menu'
    "%PS% -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$target`" %*"
    'exit /b %errorlevel%'
    ':menu'
    'if not "%PS%"=="pwsh" echo The menu needs PowerShell 7: winget install Microsoft.PowerShell & exit /b 1'
    "pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$menu`""
)
Set-Content -Path $shim -Value $cmd -Encoding Ascii

if (-not $listed) {
    Save-UserPath ($entries + $bin)
    Write-Host "Added $bin to your PATH."
}
if (($env:Path -split ';') -notcontains $bin) { $env:Path += ";$bin" }

# "Hyprland on WSL" in the Start menu (and on the desktop with -Desktop): opens the menu.
$pwsh = Get-PwshPath
$runner = if ($pwsh) { $pwsh } else { 'powershell.exe' }
$places = @($startMenu)
if ($Desktop) { $places += [Environment]::GetFolderPath('Desktop') }
foreach ($dir in $places) {
    New-Shortcut (Join-Path $dir 'Hyprland on WSL.lnk') $runner "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$menu`"" $menuShortcutNote "$env:SystemRoot\System32\wsl.exe,0"
}
Write-Host "Added ""Hyprland on WSL"" to the Start menu$(if ($Desktop) { ' and the desktop' })."

Write-Host "The hyprland-wsl command is ready. In a new terminal, type: hyprland-wsl"
