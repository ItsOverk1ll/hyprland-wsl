# Creates an Arch Linux WSL instance and installs Omarchy with hyprland-wsl into it.
#
#   .\install-omarchy.ps1                         instance "omarchy", user "omarchy"
#   .\install-omarchy.ps1 -Name omarchy2 -User me -Password secret
#
# The work is done by tools/omarchy-wsl.sh inside the instance. That script needs the
# instance restarted once, part way through; this wrapper does the restart and the second run.

param(
    [string] $Name = 'omarchy',
    [string] $User = 'omarchy',
    [string] $Password,                # default: the same as the user name
    [string] $Location                 # folder for the instance's disk; default: WSL's own choice
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = 1
if (-not $Password) { $Password = $User }

$repo = Split-Path $PSScriptRoot -Parent
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

foreach ($attempt in 1..3) {
    wsl.exe -d $Name -u root -- env "OMARCHY_USER=$User" "OMARCHY_PASSWORD=$Password" bash $script
    if ($LASTEXITCODE -eq 0) { break }
    if ($LASTEXITCODE -ne 75) { throw "The Omarchy installer stopped with an error (exit code $LASTEXITCODE)." }
    Write-Host "`nRestarting the instance and continuing ..."
    wsl.exe -t $Name | Out-Null
    Start-Sleep -Seconds 3
}
if ($LASTEXITCODE) { throw 'The Omarchy installer kept asking for a restart.' }

# The default user set by the installer applies from the next start of the instance.
wsl.exe -t $Name | Out-Null
Write-Host "`nStart it with:  $PSScriptRoot\hyprland-wsl.cmd -Distro $Name"
