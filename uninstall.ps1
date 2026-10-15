# Removes the hyprland-wsl launcher: Win+Shift+H, the hyprland-wsl command, the launcher's files
# and the copy of hyprland-wsl that install.ps1 downloaded. Your distros stay; a clone you gave
# install.ps1 with -Repo is left alone, and so is the TigerVNC viewer the sessions use.
#
#   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/Launcher/uninstall.ps1 | iex

$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$dest = Join-Path $root 'launcher'
$bin = Join-Path $root 'bin'

$hotkey = Join-Path $dest 'install-hotkey.ps1'
if (Test-Path $hotkey) { & $hotkey -Remove }

Remove-Item (Join-Path $bin 'hyprland-wsl.cmd') -ErrorAction SilentlyContinue
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$path = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$entries = @($path -split ';' | Where-Object { $_ })
$kept = @($entries | Where-Object { $_.TrimEnd('\') -ine $bin })
if ($kept.Count -ne $entries.Count) {
    $key.SetValue('Path', ($kept -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', '1', 'User')
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', $null, 'User')
}

foreach ($f in 'launcher', 'repo', 'repo-copy', 'launcher-copy', 'bin', 'settings.json', 'distros.json') {
    Remove-Item -Recurse -Force (Join-Path $root $f) -ErrorAction SilentlyContinue
}
Write-Host 'The hyprland-wsl launcher is removed. Your distros are untouched.'
