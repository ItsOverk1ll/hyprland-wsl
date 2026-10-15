# Creates a new WSL distro with Hyprland: the distro itself, an account with sudo, its hostname,
# then install.sh. The menu (launcher.ps1, "+ New distro") asks for all of this; it also works
# on its own:
#
#   .\new-distro.ps1 -Distro arch -Name myarch -User me -Hostname myarch
#   .\new-distro.ps1 -Distro mint -Name mint -User me -Location D:\WSL\mint -Mod ALT -SetDefault
#
# The password is asked for when -Password is not given. Omarchy has its own installer,
# install-omarchy.ps1, which leaves all of this to Omarchy's first-boot setup.

param(
    [Parameter(Mandatory)] [ValidateSet('arch', 'cachyos', 'kali', 'ubuntu', 'mint')] [string] $Distro,
    [Parameter(Mandatory)] [string] $Name,
    [string] $Location,                # folder for the distro's disk; default C:\WSL\<name>
    [Parameter(Mandatory)] [string] $User,
    [securestring] $Password,
    [string] $Hostname,                # default: the name
    [ValidateSet('SUPER', 'ALT')] [string] $Mod = 'SUPER',   # Hyprland's main modifier key
    [switch] $AllowPpa,                # Mint: allow the third-party PPAs without asking
    [switch] $SetDefault,              # make it WSL's default distro
    [switch] $Start                    # start it when done
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:WSL_UTF8 = 1
. (Join-Path $PSScriptRoot 'common.ps1')

# Where each distro comes from: WSL's own catalogue, or a Docker Hub image (see the README,
# "Distros without a WSL image").
$catalog = @{
    arch    = @{ Title = 'Arch Linux';       Wsl = 'archlinux' }
    kali    = @{ Title = 'Kali Linux';       Wsl = 'kali-linux' }
    ubuntu  = @{ Title = 'Ubuntu 26.04';     Wsl = 'Ubuntu-26.04' }
    cachyos = @{ Title = 'CachyOS';          Docker = 'cachyos/cachyos' }
    mint    = @{ Title = 'Linux Mint 22.3';  Docker = 'linuxmintd/mint22.3-amd64' }
}
$src = $catalog[$Distro]

if ($Name -notmatch '^[A-Za-z0-9._-]+$') { throw 'The name can have letters, digits, dots, dashes and underscores.' }
if ($User -notmatch '^[a-z_][a-z0-9_-]{0,31}$' -or $User -eq 'root') { throw 'The user name has to be lower case letters, digits, - and _, starting with a letter.' }
if (-not $Hostname) { $Hostname = $Name -replace '[^A-Za-z0-9-]', '-' }
if ($Hostname -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$') { throw 'The hostname can have letters, digits and dashes.' }
if (-not $Location) { $Location = "C:\WSL\$Name" }
if ($Name -in ((wsl.exe -l -q) | ForEach-Object { $_.Trim() })) { throw "A distro called '$Name' exists already." }
if (-not $Password) {
    $Password = Read-Host "Password for $User" -AsSecureString
    $again = Read-Host 'Again' -AsSecureString
    if ([Net.NetworkCredential]::new('', $Password).Password -cne [Net.NetworkCredential]::new('', $again).Password) { throw 'The passwords differ.' }
}
$plain = [Net.NetworkCredential]::new('', $Password).Password
if (-not $plain) { throw 'The password is empty.' }

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Green }
function Wsl([string[]] $a) { & wsl.exe @a; if ($LASTEXITCODE) { throw "wsl $($a -join ' ') failed ($LASTEXITCODE)." } }

$repoWsl = Get-RepoWslPath
$started = Get-Date

Step "Creating $($src.Title) as '$Name' in $Location"
if ($src.Wsl) {
    Wsl '--install', $src.Wsl, '--name', $Name, '--location', $Location, '--no-launch'
} else {
    # Docker image: download its layers; a single layer imports as it is, several are merged
    # into one in a throwaway distro made from the first layer.
    $images = Join-Path $env:LOCALAPPDATA "hyprland-wsl\images\$Name"
    try {
        & (Join-Path $repo 'tools\Get-DockerRootfs.ps1') -Image $src.Docker -OutDir $images
        $layers = @(Get-ChildItem $images -Filter 'layer*.tar.gz' | Sort-Object Name)
        if ($layers.Count -eq 1) {
            $rootfs = $layers[0].FullName
        } else {
            $merge = "$Name-merge"
            Wsl '--import', $merge, (Join-Path $images 'merge'), $layers[0].FullName
            try {
                $imagesWsl = '/mnt/' + $images.Substring(0, 1).ToLower() + $images.Substring(2).Replace([char]92, [char]47)
                Wsl '-d', $merge, '-u', 'root', '--', 'bash', "$repoWsl/tools/merge-layers.sh", $imagesWsl, "$imagesWsl/rootfs.tar.gz"
            } finally { wsl.exe --unregister $merge | Out-Null }
            $rootfs = Join-Path $images 'rootfs.tar.gz'
        }
        Wsl '--import', $Name, $Location, $rootfs
    } finally { Remove-Item -Recurse -Force $images -ErrorAction SilentlyContinue }
}

try {
    Step "Setting up the account $User and the hostname $Hostname"
    $envs = @("NEW_USER=$User", "NEW_HOSTNAME=$Hostname")
    if ($Distro -eq 'mint') { $envs += 'NEW_MINT=1' }
    $plain | & wsl.exe -d $Name -u root -- env @envs bash "$repoWsl/tools/new-distro-setup.sh"
    if ($LASTEXITCODE) { throw 'The account setup failed.' }

    Step 'Installing Hyprland (install.sh)'
    $envs = @("HYPR_USER=$User")
    if ($Distro -eq 'mint' -and $AllowPpa) { $envs += 'HYPRLAND_PPA=1', 'HYPRLAND_MESA_PPA=1' }
    Wsl (@('-d', $Name, '-u', 'root', '--', 'env') + $envs + @('bash', "$repoWsl/install.sh"))
    if ($Mod -eq 'SUPER') { Wsl '-d', $Name, '-u', 'root', '--', 'hyprland-wsl', 'set-mod', 'SUPER' }
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "The distro '$Name' is left as it is, to look at or retry install.sh in. Remove it from the menu (Ctrl+D) or with: wsl --unregister $Name"
    throw
}

# Restart for the hostname and default user, and skip the distro's own first-run account
# creation (its "OOBE"), since the account exists.
wsl.exe --terminate $Name | Out-Null
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | Where-Object {
    (Get-ItemProperty $_.PSPath).DistributionName -eq $Name } | ForEach-Object {
    Set-ItemProperty $_.PSPath RunOOBE 0 -Type DWord }
if ($SetDefault) { wsl.exe --set-default $Name | Out-Null }

$minutes = [math]::Round(((Get-Date) - $started).TotalMinutes)
Step "$($src.Title) is ready as '$Name' ($minutes min). User $User, hostname $Hostname, main key $Mod."
if ($Start) { & (Join-Path $PSScriptRoot 'hyprland-wsl.ps1') -Distro $Name }
