# hyprland-wsl, from nothing to the menu. Paste into PowerShell:
#
#   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/main/windows/bootstrap.ps1 | iex
#
# It checks WSL (and installs it if needed), installs PowerShell 7 and fzf, downloads
# hyprland-wsl to %LOCALAPPDATA%\hyprland-wsl\repo, adds the "hyprland-wsl" command and a Start
# menu entry, and opens the menu. Running it again updates everything in place.
#
# Written for Windows PowerShell 5.1, which every Windows 10 and 11 has.
# For testing: HYPRLAND_WSL_SOURCE=<folder> copies hyprland-wsl from that folder instead of
# downloading it, and HYPRLAND_WSL_NO_GIT=1 downloads the zip even where git is installed.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072   # TLS 1.2

$github = 'https://github.com/ItsOverk1ll/hyprland-wsl'
$root = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$repo = Join-Path $root 'repo'
$changed = New-Object System.Collections.Generic.List[string]

function Say([string] $text, [string] $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Step([string] $text) { Write-Host ''; Write-Host "==> $text" -ForegroundColor Green }
# Stops the setup with a message in plain words. (Inside "irm | iex", exit would close the
# window, so this throws a marker that the end of the script catches.)
function Stop-Here([string] $text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Yellow
    throw 'HYPRLAND_WSL_STOP'
}
function Find-Exe([string] $name, [string[]] $places) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in $places) { $f = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { return $f.FullName } }
    $null
}

function Invoke-Setup {
Write-Host ''
Write-Host 'hyprland-wsl setup' -ForegroundColor Cyan
Say @"
This sets up Hyprland, a Linux desktop, to run on Windows through WSL. Windows stays as it is.
What it may change, and where:
  - WSL, Windows' own Linux support: installed if it is missing (asks for permission; then a restart)
  - PowerShell 7 and fzf, from winget: installed if missing (Program Files and your user folder)
  - hyprland-wsl itself: downloaded to $repo
  - the "hyprland-wsl" command: $root\bin, added to your user PATH
No Linux system is installed yet: you choose one in the menu that opens at the end.
"@

# ---------------------------------------------------------------------------------------------
Step 'Checking WSL'
$os = [Environment]::OSVersion.Version
if ($os.Major -lt 10 -or $os.Build -lt 19041) {
    Stop-Here "This Windows is too old for WSL 2 (build $($os.Build)). Windows 10 version 2004 or newer is needed; Windows Update can bring it up to date."
}

$wsl = Join-Path $env:SystemRoot 'System32\wsl.exe'
$env:WSL_UTF8 = 1
$status = ''
if (Test-Path $wsl) { $status = (& $wsl --status 2>&1 | Out-String) }

if (-not (Test-Path $wsl) -or $status -match 'not installed|--install|is not enabled|Optional Component') {
    Say 'WSL is not installed yet. Installing it now; Windows asks for permission (a "Yes" prompt).'
    & $wsl --install --no-distribution
    if ($LASTEXITCODE -ne 0) {
        Stop-Here 'Installing WSL did not finish. Run PowerShell as administrator (right-click it, "Run as administrator") and paste the same command again.'
    }
    $changed.Add('Installed WSL')
    Stop-Here @"
WSL is installed. Windows needs a restart to finish it.
Restart your PC, then open PowerShell and paste the same command again; it carries on from here.
"@
}

# The Microsoft Store WSL knows --version; the old one built into Windows does not.
& $wsl --version *> $null
if ($LASTEXITCODE -ne 0) {
    Say 'Updating WSL to the current version ...'
    & $wsl --update
    if ($LASTEXITCODE -ne 0) { Stop-Here 'WSL could not be updated. Open PowerShell as administrator and run: wsl --update' }
    $changed.Add('Updated WSL')
}

if ($status -match 'Default Version:\s*1') {
    & $wsl --set-default-version 2 | Out-Null
    $changed.Add('Set WSL 2 as the default version (it was WSL 1)')
}

# WSL 2 needs the CPU's virtualization switched on in the PC's firmware. With Windows' own
# hypervisor running, Windows reports the firmware setting as off, so check that first.
$hypervisor = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
$firmware = (Get-CimInstance Win32_Processor | Select-Object -First 1).VirtualizationFirmwareEnabled
if (-not $hypervisor -and -not $firmware) {
    Stop-Here 'Virtualization is switched off in your PC''s firmware. Turn on "Intel VT-x" or "AMD SVM" in the BIOS/UEFI settings (usually under CPU or Advanced), then run this again.'
}
Say 'WSL 2 is ready.'

# ---------------------------------------------------------------------------------------------
Step 'PowerShell 7 and fzf (the menu runs in PowerShell 7 and is drawn by fzf)'
$pwsh = Find-Exe 'pwsh' @("$env:ProgramFiles\PowerShell\7\pwsh.exe")
$fzf = Find-Exe 'fzf' @("$env:LOCALAPPDATA\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Links\fzf.exe")
$winget = Find-Exe 'winget' @("$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe")
foreach ($p in @(@{ Name = 'PowerShell 7'; Id = 'Microsoft.PowerShell'; Have = $pwsh }, @{ Name = 'fzf'; Id = 'junegunn.fzf'; Have = $fzf })) {
    if ($p.Have) { Say "$($p.Name): already installed"; continue }
    if (-not $winget) {
        Stop-Here @"
$($p.Name) is needed, and winget, Windows' app installer, is not available to install it.
Install "App Installer" from the Microsoft Store (it brings winget), then run this again.
Or install $($p.Name) yourself: https://github.com/$(if ($p.Id -eq 'junegunn.fzf') { 'junegunn/fzf/releases' } else { 'PowerShell/PowerShell/releases' })
"@
    }
    Say "Installing $($p.Name) ..."
    & $winget install --id $p.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {   # that one: already installed
        Stop-Here "Installing $($p.Name) with winget did not work. Run 'winget install $($p.Id)' in PowerShell to see why, then run this again."
    }
    $changed.Add("Installed $($p.Name) (winget)")
}
$pwsh = Find-Exe 'pwsh' @("$env:ProgramFiles\PowerShell\7\pwsh.exe")
if (-not $pwsh) { Stop-Here 'PowerShell 7 was installed but cannot be found yet. Open a new PowerShell window and run this again.' }

# ---------------------------------------------------------------------------------------------
Step "hyprland-wsl itself, in $repo"
New-Item -ItemType Directory -Force $root | Out-Null
$git = if ($env:HYPRLAND_WSL_NO_GIT) { $null } else { Find-Exe 'git' @("$env:ProgramFiles\Git\cmd\git.exe") }
if ($env:HYPRLAND_WSL_SOURCE) {
    Say "Copying it from $env:HYPRLAND_WSL_SOURCE (HYPRLAND_WSL_SOURCE is set) ..."
    robocopy $env:HYPRLAND_WSL_SOURCE $repo /MIR /XD .git /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Stop-Here "Copying from $env:HYPRLAND_WSL_SOURCE did not work." }
    $changed.Add("Copied hyprland-wsl to $repo")
} elseif ($git -and (Test-Path (Join-Path $repo '.git'))) {
    Say 'Updating it ...'
    & $git -C $repo pull --ff-only --quiet
    if ($LASTEXITCODE -ne 0) { Stop-Here "Updating $repo with git did not work. Delete that folder and run this again." }
    $changed.Add("Updated hyprland-wsl in $repo")
} elseif ($git) {
    Say 'Downloading it with git ...'
    if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
    & $git clone --quiet --depth 1 "$github.git" $repo
    if ($LASTEXITCODE -ne 0) { Stop-Here 'Downloading hyprland-wsl with git did not work. Check the internet connection and run this again.' }
    $changed.Add("Downloaded hyprland-wsl to $repo")
} else {
    Say 'Downloading it ...'
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "hyprland-wsl-download-$PID"
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        Invoke-WebRequest -UseBasicParsing "$github/archive/refs/heads/main.zip" -OutFile (Join-Path $tmp 'main.zip')
    } catch {
        Stop-Here 'Downloading hyprland-wsl did not work. Check the internet connection and run this again.'
    }
    Expand-Archive (Join-Path $tmp 'main.zip') $tmp
    $unpacked = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
    Move-Item $unpacked $repo
    Remove-Item -Recurse -Force $tmp
    $changed.Add("Downloaded hyprland-wsl to $repo")
}

# ---------------------------------------------------------------------------------------------
Step 'The hyprland-wsl command'
& (Join-Path $repo 'windows\install-command.ps1') | ForEach-Object { Say $_ }
$changed.Add("Added the hyprland-wsl command ($root\bin, on your user PATH)")

# ---------------------------------------------------------------------------------------------
Step 'Done'
Say 'Changed on this PC:'
foreach ($c in $changed) { Say "  - $c" }
Say ''
Say 'From now on, open the menu by typing hyprland-wsl in any new terminal. Opening it now ...'
Start-Sleep -Seconds 2
& $pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'windows\launcher.ps1')
}

try {
    Invoke-Setup
} catch {
    if ($_.Exception.Message -ne 'HYPRLAND_WSL_STOP') {
        Write-Host ''
        Write-Host 'The setup stopped on something unexpected. Running the same command again usually helps;' -ForegroundColor Yellow
        Write-Host 'if it does not, report this line at https://github.com/ItsOverk1ll/hyprland-wsl/issues :' -ForegroundColor Yellow
        Write-Host "  $($_.Exception.Message)"
    }
}
