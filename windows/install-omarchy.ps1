# Creates an Arch Linux WSL instance, installs Omarchy with hyprland-wsl into it, and starts
# it: the first start opens Omarchy's own setup (keyboard, account, hostname, timezone), as a
# machine installed from Omarchy's USB stick for a new owner does on its first boot.
#
#   .\install-omarchy.ps1                          instance "omarchy", setup on first start
#   .\install-omarchy.ps1 -Name omarchy2 -Location C:\WSL\omarchy2
#   .\install-omarchy.ps1 -User me -Password secret -NoSetup   account made now, no setup screen
#
# The work is done by tools/omarchy-wsl.sh inside the instance. The instance is restarted once
# part way through (the install replaces systemd); this wrapper handles that.

param(
    [string] $Name = 'omarchy',
    [string] $Location,                # folder for the instance's disk; default: WSL's own choice
    [switch] $NoSetup,                 # create the account now instead of in Omarchy's setup
    [string] $User = 'omarchy',        # with -NoSetup
    [string] $Password,                # with -NoSetup; default: the same as the user name
    [switch] $NoStart                  # do not start it at the end
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = 1
if (-not $Password) { $Password = $User }

# The checkout as a path the new instance can read: under /mnt for a Windows drive. A checkout
# inside a distro (\\wsl.localhost\...) is only visible to that distro, so it is copied to
# %LOCALAPPDATA%\hyprland-wsl\repo-copy first.
$repo = Split-Path $PSScriptRoot -Parent
if ($repo -notmatch '^[A-Za-z]:\\') {
    $copy = Join-Path $env:LOCALAPPDATA 'hyprland-wsl\repo-copy'
    robocopy $repo $copy /MIR /XD .git dev-log /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not copy $repo to $copy." }
    $repo = $copy
}
$script = '/mnt/' + $repo.Substring(0, 1).ToLower() + $repo.Substring(2).Replace([char]92, [char]47) + '/tools/omarchy-wsl.sh'

$existing = (wsl.exe -l -q) | ForEach-Object { $_.Trim() }
if ($existing -notcontains $Name) {
    Write-Host "Creating the Arch Linux instance '$Name' ..."
    $create = @('--install', 'archlinux', '--name', $Name, '--no-launch')
    if ($Location) { $create += '--location', $Location }
    wsl.exe @create
    if ($LASTEXITCODE) { throw "Could not create the instance '$Name'." }
} else {
    Write-Host "Using the existing instance '$Name'."
}

$envArgs = @()
if ($NoSetup) { $envArgs = @("OMARCHY_USER=$User", "OMARCHY_PASSWORD=$Password") }
foreach ($attempt in 1..3) {
    wsl.exe -d $Name -u root -- env @envArgs bash $script
    if ($LASTEXITCODE -eq 0) { break }
    if ($LASTEXITCODE -ne 75) { throw "The Omarchy installer stopped with an error (exit code $LASTEXITCODE)." }
    Write-Host "`nRestarting the instance and continuing ..."
    wsl.exe -t $Name | Out-Null
    Start-Sleep -Seconds 3
}
if ($LASTEXITCODE) { throw 'The Omarchy installer kept asking for a restart.' }

# Restart the instance: the install replaced systemd, and settings in /etc/wsl.conf apply
# from the next start.
wsl.exe -t $Name | Out-Null
Write-Host "`nStart it later with:  $PSScriptRoot\hyprland-wsl.cmd -Distro $Name"
if (-not $NoStart) {
    Write-Host 'Starting it now ...'
    & (Join-Path $PSScriptRoot 'hyprland-wsl.ps1') -Distro $Name
}
