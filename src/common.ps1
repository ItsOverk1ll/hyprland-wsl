# Shared by the launcher's scripts (dot-sourced).

# The launcher works with a copy of hyprland-wsl itself (the main branch: install.sh, the viewer
# script, Omarchy's installer). install.ps1 downloads one to %LOCALAPPDATA%\hyprland-wsl\repo, or
# records a clone you have (-Repo) in %LOCALAPPDATA%\hyprland-wsl\settings.json.
$dataRoot = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$settingsFile = Join-Path $dataRoot 'settings.json'
$settings = if (Test-Path $settingsFile) { Get-Content $settingsFile -Raw | ConvertFrom-Json } else { $null }
$repo = if ($settings.repo) { $settings.repo } else { Join-Path $dataRoot 'repo' }
if (-not (Test-Path (Join-Path $repo 'install.sh'))) {
    throw "hyprland-wsl itself is not at $repo. Run the launcher's install.ps1 again."
}

# Where new distros get their folder (<this>\<name>): C:\WSL, or the HYPRLAND_WSL_DISTROS
# environment variable, e.g. a drive kept for projects.
$distroRoot = if ($env:HYPRLAND_WSL_DISTROS) { $env:HYPRLAND_WSL_DISTROS.TrimEnd('\') } else { 'C:\WSL' }

# A Windows folder as a path every WSL distro can read: under /mnt for a drive letter. A folder
# inside a distro (\\wsl.localhost\...) is only visible to that distro, so it is copied to
# %LOCALAPPDATA%\hyprland-wsl\<name> first.
function ConvertTo-WslPath([string] $path, [string] $copyName) {
    if ($path -notmatch '^[A-Za-z]:\\') {
        $copy = Join-Path $dataRoot $copyName
        robocopy $path $copy /MIR /XD .git dev-log /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Could not copy $path to $copy." }
        $path = $copy
    }
    '/mnt/' + $path.Substring(0, 1).ToLower() + $path.Substring(2).TrimEnd('\').Replace([char]92, [char]47)
}

function Get-RepoWslPath { ConvertTo-WslPath $repo 'repo-copy' }
function Get-LauncherWslPath { ConvertTo-WslPath $PSScriptRoot 'launcher-copy' }
