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
    [string] $Location,                # folder for the distro's disk; default C:\WSL\<name> (see common.ps1)
    [Parameter(Mandatory)] [string] $User,
    [securestring] $Password,
    [string] $Hostname,                # default: the name
    [ValidateSet('SUPER', 'ALT')] [string] $Mod = 'SUPER',   # Hyprland's main modifier key
    [switch] $AllowPpa,                # Mint: allow the third-party PPAs without asking
    [switch] $SetDefault,              # make it WSL's default distro
    [switch] $Start,                   # start it when done
    [switch] $ShowOutput,              # show everything the tools print, not only the steps
    [switch] $KeepOnFailure            # leave a half-made distro in place to look at
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:WSL_UTF8 = 1
. (Join-Path $PSScriptRoot 'common.ps1')

# Where each distro comes from: WSL's own catalogue, or a Docker Hub image (see the README,
# "Distros without a WSL image").
$catalog = @{
    arch    = @{ Title = 'Arch Linux';       Wsl = 'archlinux';                   Minutes = '3 to 5' }
    kali    = @{ Title = 'Kali Linux';       Wsl = 'kali-linux';                  Minutes = '3 to 5' }
    ubuntu  = @{ Title = 'Ubuntu 26.04';     Wsl = 'Ubuntu-26.04';                Minutes = '3 to 5' }
    cachyos = @{ Title = 'CachyOS';          Docker = 'cachyos/cachyos';           Minutes = '3 to 6' }
    mint    = @{ Title = 'Linux Mint 22.3';  Docker = 'linuxmintd/mint22.3-amd64'; Minutes = '4 to 8' }
}
$src = $catalog[$Distro]

if ($Name -notmatch '^[A-Za-z0-9._-]+$') { throw 'The name can have letters, digits, dots, dashes and underscores.' }
if ($User -notmatch '^[a-z_][a-z0-9_-]{0,31}$' -or $User -eq 'root') { throw 'The user name has to be lower case letters, digits, - and _, starting with a letter.' }
if (-not $Hostname) { $Hostname = $Name -replace '[^A-Za-z0-9-]', '-' }
if ($Hostname -notmatch '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$') { throw 'The hostname can have letters, digits and dashes.' }
if (-not $Location) { $Location = "$distroRoot\$Name" }
if ($Name -in ((wsl.exe -l -q) | ForEach-Object { $_.Trim() })) { throw "A distro called '$Name' exists already." }
if (-not $Password) {
    $Password = Read-Host "Password for $User" -AsSecureString
    $again = Read-Host 'Again' -AsSecureString
    if ([Net.NetworkCredential]::new('', $Password).Password -cne [Net.NetworkCredential]::new('', $again).Password) { throw 'The passwords differ.' }
}
$plain = [Net.NetworkCredential]::new('', $Password).Password
if (-not $plain) { throw 'The password is empty.' }

# What a newcomer sees is one line per step with a rough time; everything the tools print goes
# to a log file kept for bug reports (-ShowOutput shows it on screen too).
$log = New-LogFile "new-$Name"
"hyprland-wsl new-distro.ps1: $Distro as '$Name' in $Location, $(Get-Date)" | Set-Content $log -Encoding utf8
function Step($text, $estimate) {
    Write-Host "`n==> $text$(if ($estimate) { "  (about $estimate)" })" -ForegroundColor Green
    "`n==> $text" | Add-Content $log -Encoding utf8
}
# Stops with one plain sentence: what did not work, what to try, where the log is.
function Fail($what, $try) {
    # Some causes are recognisable in the output; they get a more precise suggestion.
    $tail = (Get-Content $log -Tail 30 -ErrorAction SilentlyContinue) -join "`n"
    if ($tail -match 'PATH_NOT_FOUND|cannot find the path') { $try = "The folder $Location cannot be used; check that its drive exists, or choose another folder." }
    elseif ($tail -match 'DISK_FULL|No space left|not enough space') { $try = 'The drive is full; free a few GB, or choose a folder on another drive.' }
    elseif ($tail -match 'Could not resolve|Temporary failure in name resolution|timed out|Connection refused') { $try = 'Check the internet connection and try again.' }
    throw "$what did not work. $try The full output is in $log"
}
# Runs a command (a script block) with its output in the log, and stops with Fail if it fails.
function Run($what, $try, [scriptblock] $command) {
    $global:LASTEXITCODE = 0
    try {
        if ($ShowOutput) { & $command 2>&1 | Tee-Object -FilePath $log -Append | Out-Host }
        else { & $command *>> $log }
    } catch {
        "$_" | Add-Content $log -Encoding utf8
        Fail $what $try
    }
    if ($LASTEXITCODE) { "exit code $LASTEXITCODE" | Add-Content $log -Encoding utf8; Fail $what $try }
}

$repoWsl = Get-RepoWslPath
$started = Get-Date
$net = 'Check the internet connection and try again.'
Write-Host "Installing $($src.Title) as '$Name'. This takes about $($src.Minutes) minutes on a fast connection." -ForegroundColor Cyan

$made = $false
try {
    if ($src.Wsl) {
        Step "Downloading and creating $($src.Title)" '1 minute'
        Run "Downloading $($src.Title)" $net { wsl.exe --install $src.Wsl --name $Name --location $Location --no-launch }
    } else {
        # Docker image: download its layers; a single layer imports as it is, several are merged
        # into one in a throwaway distro made from the first layer.
        $images = Join-Path $dataRoot "images\$Name"
        try {
            Step "Downloading $($src.Title)" '1 to 2 minutes'
            Run "Downloading $($src.Title)" $net { & (Join-Path $repo 'tools\Get-DockerRootfs.ps1') -Image $src.Docker -OutDir $images }
            $layers = @(Get-ChildItem $images -Filter 'layer*.tar.gz' | Sort-Object Name)
            $unpack = 'Try again; the download may have been incomplete.'
            if ($layers.Count -eq 1) {
                $rootfs = $layers[0].FullName
            } else {
                Step 'Unpacking it' '1 minute'
                $merge = "$Name-merge"
                Run 'Unpacking the download' $unpack { wsl.exe --import $merge (Join-Path $images 'merge') $layers[0].FullName }
                try {
                    $imagesWsl = '/mnt/' + $images.Substring(0, 1).ToLower() + $images.Substring(2).Replace([char]92, [char]47)
                    Run 'Unpacking the download' $unpack { wsl.exe -d $merge -u root -- bash "$repoWsl/tools/merge-layers.sh" $imagesWsl "$imagesWsl/rootfs.tar.gz" }
                } finally { wsl.exe --unregister $merge *> $null }
                $rootfs = Join-Path $images 'rootfs.tar.gz'
            }
            Step "Creating $($src.Title)"
            Run "Creating $($src.Title)" 'Check that the drive has a few GB free and try again.' { wsl.exe --import $Name $Location $rootfs }
        } finally { Remove-Item -Recurse -Force $images -ErrorAction SilentlyContinue }
    }
    $made = $true

    $time = if ($Distro -in 'arch', 'cachyos') { '1 to 2 minutes' } else { '1 minute' }
    Step "Setting up your account ($User) and the computer name ($Hostname)" $time
    $envs = @("NEW_USER=$User", "NEW_HOSTNAME=$Hostname")
    if ($Distro -eq 'mint') { $envs += 'NEW_MINT=1' }
    Run 'Setting up the account' "Try again in a few minutes; the distro's download servers may be busy." {
        $plain | wsl.exe -d $Name -u root -- env @envs bash "$repoWsl/tools/new-distro-setup.sh" }

    Step 'Installing Hyprland and the desktop' '2 to 5 minutes'
    $envs = @("HYPR_USER=$User")
    if ($Distro -eq 'mint' -and $AllowPpa) { $envs += 'HYPRLAND_PPA=1', 'HYPRLAND_MESA_PPA=1' }
    $try = 'Try again; if it fails again, please report it with the log file.'
    Run 'Installing Hyprland' $try { wsl.exe -d $Name -u root -- env @envs bash "$repoWsl/install.sh" }
    if ($Mod -eq 'SUPER') { Run 'Setting the Windows key as the main key' $try { wsl.exe -d $Name -u root -- hyprland-wsl set-mod SUPER } }
} catch {
    Write-Host "`n$($_.Exception.Message)" -ForegroundColor Yellow
    if ($made -and -not $KeepOnFailure) {
        # A half-made distro is of no use to a newcomer; take it away so a retry starts clean.
        wsl.exe --unregister $Name *> $null
        if ((Test-Path $Location) -and -not (Get-ChildItem $Location -Force)) { Remove-Item $Location }
        Write-Host "The half-made '$Name' was removed again, so trying again starts clean (-KeepOnFailure keeps it)."
    } elseif ($made) {
        Write-Host "'$Name' is left as it is. Remove it from the menu (Ctrl+D) or with: wsl --unregister $Name"
    }
    exit 1
}

# Restart for the hostname and default user, and skip the distro's own first-run account
# creation (its "OOBE"), since the account exists.
wsl.exe --terminate $Name | Out-Null
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | Where-Object {
    (Get-ItemProperty $_.PSPath).DistributionName -eq $Name } | ForEach-Object {
    Set-ItemProperty $_.PSPath RunOOBE 0 -Type DWord }
if ($SetDefault) { wsl.exe --set-default $Name | Out-Null }
Add-CreatedDistro $Name
# Its own Start menu entry, e.g. "Arch Linux (myarch)"; removing the distro removes it.
$shortcut = Set-DistroShortcut $Name "$($src.Title) ($Name)"

$minutes = [math]::Max(1, [math]::Round(((Get-Date) - $started).TotalMinutes))
Step "$($src.Title) is ready as '$Name' ($minutes min). User $User, computer name $Hostname, main key $Mod."
Write-Host "Start it from the Start menu ('$([IO.Path]::GetFileNameWithoutExtension($shortcut))') or the hyprland-wsl menu."
if ($Start) { & (Join-Path $PSScriptRoot 'hyprland-wsl.ps1') -Distro $Name }
