# Removes WSL distros and what belongs to them outside WSL:
#
#   - the distro itself (wsl --unregister: its disk and everything in it)
#   - its folder, when nothing else is left in it
#   - its Windows Terminal profiles: the one WSL made, and ones you made yourself that start it
#     (a command line with "-d NAME", "--distribution NAME" or hyprland-wsl's "-Distro NAME")
#   - the Microsoft Store app it was installed from, if any (Kali's, Ubuntu's, ...)
#
#   .\remove-distro.ps1 -Name archfresh            asks you to type the name first
#   .\remove-distro.ps1 -Name archfresh -Force
#   .\remove-distro.ps1 -Name old1, old2 -ProfilesOnly    Terminal profiles of distros already gone
#
# Terminal's settings are backed up to %LOCALAPPDATA%\hyprland-wsl\backups before they change.
# The menu (launcher.ps1, Ctrl+D) uses Get-DistroLeftovers and Remove-DistroCompletely from here.

param(
    # Not called $Name: the menu dot-sources this file, and a typed $Name would turn its own
    # $name into a list.
    [Alias('Name')] [string[]] $DistroName,
    [switch] $Force,
    [switch] $ProfilesOnly
)

. (Join-Path $PSScriptRoot 'common.ps1')
$lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$terminalSettings = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ }

# Everything that belongs to the distro, looked up while it still exists.
function Get-DistroLeftovers([string] $distro) {
    $key = Get-ChildItem $lxss -ErrorAction SilentlyContinue |
        Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq $distro } | Select-Object -First 1
    $reg = if ($key) { Get-ItemProperty $key.PSPath }
    # The profile WSL makes is a Terminal "fragment" named by the profile's id; it also hides
    # (updates) the profile of WSL's older profile generator.
    $guids = @()
    if ($reg.TerminalProfilePath -and (Test-Path $reg.TerminalProfilePath)) {
        $guids += [IO.Path]::GetFileNameWithoutExtension($reg.TerminalProfilePath)
        try {
            (Get-Content $reg.TerminalProfilePath -Raw | ConvertFrom-Json).profiles |
                ForEach-Object { $guids += $_.guid, $_.updates }
        } catch {}
    }
    $guids = @($guids | Where-Object { $_ } | ForEach-Object { $_.ToLower() } | Select-Object -Unique)
    $ref = [regex]::Escape($distro)
    $pattern = "(?i)(^|\s)(-d|--distribution|-Distro)\s+[`"']?$ref([`"']|\s|$)"
    $profiles = foreach ($file in $terminalSettings) {
        $s = Get-Content $file -Raw | ConvertFrom-Json
        foreach ($p in @($s.profiles.list)) {
            $wslMade = $p.source -match 'WSL|Lxss' -and $p.name -eq $distro
            $byId = $key -and $p.commandline -and $p.commandline.ToLower().Contains($key.PSChildName.ToLower())   # wsl --distribution-id
            if (($p.guid -and $p.guid.ToLower() -in $guids) -or $wslMade -or $byId -or ($p.commandline -match $pattern)) {
                [pscustomobject]@{ File = $file; Guid = $p.guid; Name = $p.name }
            }
        }
    }
    $package = if ($reg.PackageFamilyName) { Get-AppxPackage | Where-Object PackageFamilyName -eq $reg.PackageFamilyName }
    [pscustomobject]@{
        Name     = $distro
        Exists   = [bool]$reg
        Base     = if ($reg.BasePath) { $reg.BasePath -replace '^\\\\\?\\', '' }
        Profiles = @($profiles)
        Shortcuts = @(Find-Shortcuts (Get-DistroShortcutNote $distro))
        MadeHere = $distro -in (Get-CreatedDistros)
        Package  = $package
    }
}

function Remove-TerminalProfiles($profiles) {
    foreach ($group in ($profiles | Group-Object File)) {
        $file = $group.Name
        $backups = Join-Path $env:LOCALAPPDATA 'hyprland-wsl\backups'
        New-Item -ItemType Directory -Force $backups | Out-Null
        # Never overwrite an earlier backup: several can be made within a second.
        $stem = "terminal-settings-{0:yyyyMMdd-HHmmss}" -f (Get-Date)
        $n = 1; $backup = Join-Path $backups "$stem.json"
        while (Test-Path $backup) { $n++; $backup = Join-Path $backups "$stem-$n.json" }
        Copy-Item $file $backup
        $s = Get-Content $file -Raw | ConvertFrom-Json
        $drop = @($group.Group | ForEach-Object { "$($_.Guid)|$($_.Name)" })
        $s.profiles.list = @($s.profiles.list | Where-Object { "$($_.guid)|$($_.name)" -notin $drop })
        # A removed default profile would leave Terminal without one; fall back to the first.
        if ($s.defaultProfile -and $s.defaultProfile -notin $s.profiles.list.guid) {
            $s.defaultProfile = ($s.profiles.list | Where-Object { -not $_.hidden } | Select-Object -First 1).guid
        }
        $s | ConvertTo-Json -Depth 100 | Set-Content $file -Encoding utf8NoBOM
    }
}

function Remove-DistroCompletely($leftovers) {
    if ($leftovers.Exists) {
        $env:WSL_UTF8 = 1
        wsl.exe --unregister $leftovers.Name | Out-Host
        if ($LASTEXITCODE) { throw "wsl --unregister $($leftovers.Name) failed." }
    }
    # wsl leaves the folder; remove it when nothing else is in it.
    if ($leftovers.Base -and (Test-Path $leftovers.Base) -and -not (Get-ChildItem $leftovers.Base -Force)) {
        Remove-Item $leftovers.Base
    }
    if ($leftovers.Profiles) { Remove-TerminalProfiles $leftovers.Profiles }
    $leftovers.Shortcuts | Remove-Item -ErrorAction SilentlyContinue
    Remove-CreatedDistro $leftovers.Name
    if ($leftovers.Package) { $leftovers.Package | Remove-AppxPackage }
}

function Format-Leftovers($leftovers) {
    $lines = @()
    if ($leftovers.Exists) { $lines += "the distro and its disk$(if ($leftovers.Base) { " ($($leftovers.Base))" })" }
    foreach ($p in $leftovers.Profiles) { $lines += "Windows Terminal profile '$($p.Name)'" }
    foreach ($s in $leftovers.Shortcuts) { $lines += "shortcut '$([IO.Path]::GetFileNameWithoutExtension($s))'" }
    if ($leftovers.Package) { $lines += "Microsoft Store app $($leftovers.Package.Name)" }
    $lines
}

# For distros hyprland-wsl did not create: they may hold someone's own files and setup.
$notMadeHereWarning = 'This distro was not made by hyprland-wsl. It may hold your own files, programs and settings, which are deleted with it.'

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced: functions only

$ErrorActionPreference = 'Stop'
foreach ($n in $DistroName) {
    $l = Get-DistroLeftovers $n
    if ($ProfilesOnly) { $l.Exists = $false; $l.Base = $null; $l.Package = $null; $l.Shortcuts = @() }
    $what = @(Format-Leftovers $l)
    if (-not $what) { Write-Host "${n}: nothing to remove."; continue }
    Write-Host "${n}:"; $what | ForEach-Object { Write-Host "  - $_" }
    if ($l.Exists -and -not $l.MadeHere) { Write-Host $notMadeHereWarning -ForegroundColor Yellow }
    if (-not $Force -and (Read-Host "Type the name ($n) to remove all of this, or Enter to keep it") -cne $n) { continue }
    Remove-DistroCompletely $l
    Write-Host "Removed."
}
