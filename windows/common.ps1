# Shared by the Windows scripts (dot-sourced).

$repo = Split-Path $PSScriptRoot -Parent
$dataRoot = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'

# Where new distros get their folder (<this>\<name>): C:\WSL, or the HYPRLAND_WSL_DISTROS
# environment variable, e.g. a drive kept for projects.
$distroRoot = if ($env:HYPRLAND_WSL_DISTROS) { $env:HYPRLAND_WSL_DISTROS.TrimEnd('\') } else { 'C:\WSL' }

# The checkout as a path that every WSL distro can read: under /mnt for a Windows drive. A
# checkout inside a distro (\\wsl.localhost\...) is only visible to that distro, so it is copied
# to %LOCALAPPDATA%\hyprland-wsl\repo-copy first.
function Get-RepoWslPath {
    $src = $repo
    if ($src -notmatch '^[A-Za-z]:\\') {
        $src = Join-Path $dataRoot 'repo-copy'
        robocopy $repo $src /MIR /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Could not copy $repo to $src." }
    }
    '/mnt/' + $src.Substring(0, 1).ToLower() + $src.Substring(2).TrimEnd('\').Replace([char]92, [char]47)
}
