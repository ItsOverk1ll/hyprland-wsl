# Removes hyprland-wsl from Windows: the "hyprland-wsl" command, its Start menu and desktop
# shortcuts, the menu's cache and logs, the downloaded TigerVNC viewer, and the copy of
# hyprland-wsl that the one-line install downloaded. It never removes a distro: remove those
# first, from the menu (Ctrl+D) or with remove-distro.ps1, if you want them gone.
#
#   .\uninstall.ps1           lists what it removes, then asks
#   .\uninstall.ps1 -Force    without asking
#
# Works in Windows PowerShell 5.1. Inside a distro, ./uninstall.sh removes hyprland-wsl there.

param([switch] $Force)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$env:WSL_UTF8 = 1
$downloaded = Join-Path $dataRoot 'repo'
$fromDownload = $repo.TrimEnd('\') -ieq $downloaded
$hasDownload = Test-Path $downloaded

# Program error output must not stop Windows PowerShell 5.1 here (no distros prints to stderr).
$ErrorActionPreference = 'Continue'
$distros = @((wsl.exe -l -q 2>&1) | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and $_ -notmatch ' ' })
$ErrorActionPreference = 'Stop'
$made = @(Get-CreatedDistros | Where-Object { $_ -in $distros })

Write-Host 'Uninstall hyprland-wsl from Windows' -ForegroundColor Cyan
Write-Host 'This removes:'
Write-Host '  - the hyprland-wsl command'
Write-Host '  - "Hyprland on WSL" and the distro entries in the Start menu (and on the desktop)'
Write-Host "  - the menu's cache, logs and the downloaded TigerVNC viewer ($dataRoot)"
if ($hasDownload) { Write-Host "  - the downloaded copy of hyprland-wsl ($downloaded)" }
Write-Host ''
if ($distros) {
    Write-Host "Your distros stay, with everything in them: $($distros -join ', ')." -ForegroundColor Yellow
    Write-Host 'To remove one too, do that first, from the menu (Ctrl+D), then uninstall.' -ForegroundColor Yellow
} else {
    Write-Host 'No distro is removed.'
}
Write-Host 'WSL, PowerShell 7 and fzf stay installed; Windows'' "Installed apps" settings can remove them.'
if (-not $Force -and (Read-Host 'Uninstall? (y/N)') -notmatch '^y') { Write-Host 'Nothing was changed.'; return }

& (Join-Path $PSScriptRoot 'install-command.ps1') -Remove | Out-Null
# What the menu keeps for itself. A list of the distros it made stays while any of them exists,
# so a later install still knows them; Terminal settings backups stay too.
foreach ($f in 'bin', 'distros.json', 'logs', 'images', 'repo-copy', 'vncviewer64.exe', 'vncviewer64.exe.download') {
    Remove-Item -Recurse -Force (Join-Path $dataRoot $f) -ErrorAction SilentlyContinue
}
if (-not $made) { Remove-Item -Force $createdFile -ErrorAction SilentlyContinue }
Remove-Item -Recurse -Force (Join-Path $env:TEMP 'hyprland-wsl-launcher') -ErrorAction SilentlyContinue
if ($hasDownload) {
    Set-Location $env:USERPROFILE
    Remove-Item -Recurse -Force $downloaded
}
if (-not (Get-ChildItem $dataRoot -Force -ErrorAction SilentlyContinue)) { Remove-Item $dataRoot -ErrorAction SilentlyContinue }
Write-Host 'hyprland-wsl is uninstalled.' -ForegroundColor Green
if (-not $fromDownload) { Write-Host "The clone it ran from, $repo, is yours and was left alone." }
