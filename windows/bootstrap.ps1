# hyprland-wsl, from nothing to the menu. Paste into PowerShell:
#
#   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/main/windows/bootstrap.ps1 | iex
#
# It checks WSL (and installs it if needed), installs PowerShell 7 and fzf, downloads
# hyprland-wsl to %LOCALAPPDATA%\hyprland-wsl\repo, adds the "hyprland-wsl" command and a Start
# menu entry, and opens the menu. Running it again updates everything in place.
#
# Written for Windows PowerShell 5.1, which every Windows 10 and 11 has. The winget and
# PowerShell 7 handling comes from BetterHotkeys' installer, which was tested on fresh Windows 10
# and 11 installs (https://github.com/ItsOverk1ll/BetterHotkeys).
# For testing: HYPRLAND_WSL_SOURCE=<folder> copies hyprland-wsl from that folder instead of
# downloading it, HYPRLAND_WSL_NO_GIT=1 downloads the zip even where git is installed, and
# HYPRLAND_WSL_SKIP_VIRT=1 carries on without virtualization (a virtual machine that cannot
# have it: everything installs, but WSL 2 distros will not start).

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Windows PowerShell 5.1 may not use TLS 1.2 by default, which GitHub requires.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072

$github = 'https://github.com/ItsOverk1ll/hyprland-wsl'
$root = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$repo = Join-Path $root 'repo'
$changed = New-Object System.Collections.Generic.List[string]
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }

function Say([string] $text, [string] $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Info([string] $text) { Write-Host "  $text" -ForegroundColor DarkGray }
function Step([string] $text) { Write-Host ''; Write-Host "==> $text" -ForegroundColor Green }
# Stops the setup with a message in plain words. (Inside "irm | iex", exit would close the
# window, so this throws a marker that the end of the script catches.)
function Stop-Here([string] $text) {
    Write-Host ''
    Write-Host $text -ForegroundColor Yellow
    throw 'HYPRLAND_WSL_STOP'
}

# Runs a program and returns its output, error output included, as text. In Windows PowerShell
# 5.1 any error output from a program stops the script while $ErrorActionPreference is 'Stop',
# even when it is redirected, so this relaxes it for the call. $LASTEXITCODE is kept.
function Invoke-Program([scriptblock] $call) {
    $ErrorActionPreference = 'Continue'
    & $call 2>&1 | ForEach-Object { "$_" }
}

# Downloads url to file. HttpWebRequest: Invoke-WebRequest in 5.1 is about ten times slower.
function Get-File([string] $url, [string] $file, [string] $label) {
    $request = [Net.HttpWebRequest]::Create($url)
    $request.Timeout = 60000; $request.ReadWriteTimeout = 60000
    $request.UserAgent = 'hyprland-wsl'
    $response = $request.GetResponse()
    $total = $response.ContentLength
    $in = $response.GetResponseStream()
    $out = [IO.File]::Create($file)
    try {
        $buffer = New-Object byte[] 1MB
        $done = 0; $shown = -25
        while (($n = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $out.Write($buffer, 0, $n); $done += $n
            if ($total -gt 0) {
                $pct = [int](100 * $done / $total)
                if ($pct -ge $shown + 25) { $shown = $pct - ($pct % 25); Info ("{0}: {1}% of {2:N0} MB" -f $label, $pct, ($total / 1MB)) }
            }
        }
    } finally { $out.Close(); $in.Close(); $response.Close() }
}

function Find-Exe([string] $name, [string[]] $places) {
    $c = Get-Command $name -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in $places) { $f = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1; if ($f) { return $f.FullName } }
    $null
}

# ---- winget ------------------------------------------------------------------------------------
# A winget that answers, or $null.
function Find-Winget {
    foreach ($path in @((Get-Command winget -ErrorAction SilentlyContinue).Source, "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe")) {
        if ($path -and (Test-Path $path)) {
            try { if ((Invoke-Program { & $path --version }) -match '^v\d') { return $path } } catch {}
        }
    }
    $null
}
function Get-WingetVersion([string] $path) {
    $text = (Invoke-Program { & $path --version }) | Select-Object -First 1
    if ($text -match '^v(\d+\.\d+(\.\d+)?)') { [version]$Matches[1] }
}
# App Installer, which contains winget, with its dependencies, from winget's GitHub releases.
function Install-WingetFromGitHub {
    $tmp = Join-Path $env:TEMP 'hyprland-wsl-winget'
    try {
        New-Item -ItemType Directory -Force $tmp | Out-Null
        $base = 'https://github.com/microsoft/winget-cli/releases/latest/download'
        Get-File "$base/DesktopAppInstaller_Dependencies.zip" "$tmp\deps.zip" 'winget dependencies'
        Get-File "$base/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" "$tmp\winget.msixbundle" 'winget'
        Info 'Installing winget (this can take a minute) ...'
        Expand-Archive "$tmp\deps.zip" "$tmp\deps" -Force
        $deps = @(Get-ChildItem "$tmp\deps" -Recurse -Include *.appx, *.msix |
            Where-Object { $_.FullName -match "\\$arch\\" } | Select-Object -ExpandProperty FullName)
        if ($deps) { Add-AppxPackage -Path "$tmp\winget.msixbundle" -DependencyPath $deps -ForceApplicationShutdown }
        else { Add-AppxPackage -Path "$tmp\winget.msixbundle" -ForceApplicationShutdown }
    } catch { Info "That did not work: $($_.Exception.Message)" }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
# winget comes with "App Installer". If it is missing or broken, first register the copy Windows
# already has (common on a new account), then install it from GitHub. An old winget (older
# Windows 10 images) lacks options used here, so it is updated the same way.
function Get-Winget {
    $w = Find-Winget
    if (-not $w) {
        Info 'Registering App Installer (winget) ...'
        try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe } catch {}
        $w = Find-Winget
    }
    if (-not $w) {
        Info 'Downloading winget from GitHub (about 300 MB) ...'
        Install-WingetFromGitHub
        $w = Find-Winget
    } else {
        $v = Get-WingetVersion $w
        if ($v -and $v -lt [version]'1.6.0') {
            Info "winget $v is too old; updating it from GitHub (about 300 MB) ..."
            Install-WingetFromGitHub
            $w = Find-Winget
        }
    }
    $w
}
# Installs a package with winget, silently, in at most ten minutes. True when it is there after.
function Install-WithWinget([string] $winget, [string] $id, [string] $name) {
    $log = Join-Path $env:TEMP "hyprland-wsl-winget-$id.log"
    $wingetArgs = @('install', '--id', $id, '--exact', '--source', 'winget', '--silent', '--accept-source-agreements',
        '--accept-package-agreements', '--disable-interactivity')
    $proc = Start-Process $winget -ArgumentList $wingetArgs -NoNewWindow -PassThru -RedirectStandardOutput $log
    $null = $proc.Handle   # makes ExitCode readable later
    if (-not $proc.WaitForExit(600000)) { $proc.Kill(); Info "$name took longer than 10 minutes and was stopped."; return $false }
    # 0x8A15002B, 0x8A150061: already installed; 0x8A150109: done after a restart
    $ok = $proc.ExitCode -in 0, -1978335189, -1978335135, -1978334967
    if (-not $ok) { Info "winget could not install $name (exit $($proc.ExitCode)); details in $log" }
    $ok
}

# ---- PowerShell 7 ------------------------------------------------------------------------------
# A PowerShell 7 that actually runs, or $null. A pwsh.exe can exist and still fail: a Microsoft
# Store copy without a license (common on VMs) stops with "No applicable app licenses found".
function Find-Pwsh {
    $candidates = @("$env:ProgramFiles\PowerShell\7\pwsh.exe") + @(Get-Command pwsh -All -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })
    foreach ($path in $candidates) {
        if (-not $path -or -not (Test-Path $path)) { continue }
        try {
            $major = (Invoke-Program { & $path -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.Major' }) | Select-Object -Last 1
            if ($major -match '^\d+$' -and [int]$major -ge 7) { return $path }
        } catch {}
    }
    $null
}
# PowerShell 7 from the official MSI on GitHub (Windows asks for permission).
function Install-PwshMsi {
    $release = Invoke-RestMethod 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -Headers @{ 'User-Agent' = 'hyprland-wsl' }
    $asset = $release.assets | Where-Object { $_.name -match "-win-$arch\.msi$" } | Select-Object -First 1
    if (-not $asset) { throw "no $arch installer in PowerShell $($release.tag_name)" }
    $msi = Join-Path $env:TEMP $asset.name
    Get-File $asset.browser_download_url $msi 'PowerShell 7'
    Info 'Installing PowerShell 7 (Windows asks for permission) ...'
    $proc = Start-Process msiexec.exe -ArgumentList '/i', "`"$msi`"", '/quiet', '/norestart', 'ADD_PATH=1' -Verb RunAs -Wait -PassThru
    Remove-Item $msi -ErrorAction SilentlyContinue
    if ($proc.ExitCode -notin 0, 3010) { throw "the installer stopped (exit $($proc.ExitCode))" }
}

function Find-Fzf {
    Find-Exe 'fzf' @("$env:LOCALAPPDATA\Microsoft\WinGet\Links\fzf.exe", "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe", "$env:USERPROFILE\scoop\shims\fzf.exe")
}

function Invoke-Setup {
Write-Host ''
Write-Host 'hyprland-wsl setup' -ForegroundColor Cyan
Say @"
This sets up Hyprland, a Linux desktop, to run on Windows through WSL. Windows stays as it is.
What it may change, and where:
  - WSL, Windows' own Linux support: installed if it is missing (asks for permission; then a restart)
  - winget, PowerShell 7 and fzf: installed if missing (Program Files and your user folder)
  - hyprland-wsl itself: downloaded to $repo
  - the "hyprland-wsl" command: $root\bin, added to your user PATH
  - a "Hyprland on WSL" entry in your Start menu (and, if you want, on the desktop)
No Linux system is installed yet: you choose one in the menu that opens at the end.
"@

# ---------------------------------------------------------------------------------------------
Step 'Checking WSL'
$os = [Environment]::OSVersion.Version
if ($os.Major -lt 10 -or $os.Build -lt 19044) {
    Stop-Here "This Windows is too old for WSL 2 (build $($os.Build)). Windows 10 version 21H2 or newer is needed; Windows Update can bring it up to date."
}

$wsl = Join-Path $env:SystemRoot 'System32\wsl.exe'
$env:WSL_UTF8 = 1
# wsl's output as text. The old WSL built into Windows ignores WSL_UTF8 and writes UTF-16, which
# Windows PowerShell reads with a zero between every letter; those are taken out.
function Invoke-Wsl([string[]] $wslArgs) {
    if (-not (Test-Path $wsl)) { $global:LASTEXITCODE = 1; return '' }
    ((Invoke-Program { & $wsl @wslArgs }) -join "`n") -replace "`0", ''
}

# WSL 2 needs the CPU's virtualization switched on. With Windows' own hypervisor running, Windows
# reports the firmware setting as off, so that is checked first. Checked before anything is
# installed, so that nobody restarts for nothing.
$computer = Get-CimInstance Win32_ComputerSystem
$firmware = (Get-CimInstance Win32_Processor | Select-Object -First 1).VirtualizationFirmwareEnabled
if (-not $computer.HypervisorPresent -and -not $firmware -and $env:HYPRLAND_WSL_SKIP_VIRT) {
    Say 'Virtualization is off; carrying on anyway (HYPRLAND_WSL_SKIP_VIRT is set). WSL 2 distros will not start here.' Yellow
} elseif (-not $computer.HypervisorPresent -and -not $firmware) {
    if ("$($computer.Manufacturer) $($computer.Model)" -match 'VirtualBox|VMware|Virtual Machine|QEMU|KVM|Parallels') {
        Stop-Here "This Windows runs in a virtual machine ($($computer.Model)) without nested virtualization, which WSL 2 needs. Shut the virtual machine down and turn it on in its settings (VirtualBox: Settings > System > Processor > Enable Nested VT-x/AMD-V; VMware: Virtualize Intel VT-x/EPT), then run this again."
    }
    Stop-Here 'Virtualization is switched off in your PC''s firmware. Turn on "Intel VT-x" or "AMD SVM" in the BIOS/UEFI settings (usually under CPU or Advanced), then run this again.'
}

# The current WSL knows --version. The old one built into Windows 10 does not, and lacks most of
# what is needed here (no --update, no --install --no-distribution); the current one is
# installed from Microsoft's release on GitHub, where it takes over from the old one.
Invoke-Wsl '--version' | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say 'This PC has the old WSL that came with Windows. Installing the current WSL from Microsoft;'
    Say 'Windows asks for permission (a "Yes" prompt).'
    try {
        $release = Invoke-RestMethod 'https://api.github.com/repos/microsoft/WSL/releases/latest' -Headers @{ 'User-Agent' = 'hyprland-wsl' }
        $asset = $release.assets | Where-Object { $_.name -match "^wsl\.[\d.]+\.$arch\.msi$" } | Select-Object -First 1
        if (-not $asset) { throw "no $arch installer in WSL $($release.tag_name)" }
        $msi = Join-Path $env:TEMP $asset.name
        Get-File $asset.browser_download_url $msi "WSL $($release.tag_name)"
        $proc = Start-Process msiexec.exe -ArgumentList '/i', "`"$msi`"", '/quiet', '/norestart' -Verb RunAs -Wait -PassThru
        Remove-Item $msi -ErrorAction SilentlyContinue
        if ($proc.ExitCode -notin 0, 3010) { throw "the installer stopped (exit $($proc.ExitCode))" }
    } catch { Info "That did not work: $($_.Exception.Message)" }
    Invoke-Wsl '--version' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Stop-Here 'The current WSL could not be installed. Install "Windows Subsystem for Linux" from the Microsoft Store (or run Windows Update), then paste the same command again.'
    }
    $changed.Add('Installed the current WSL')
}

# The current WSL says when the Windows features it needs are not switched on yet.
# A WSL without distros yet also mentions "wsl --install", so only these count as missing features.
$status = Invoke-Wsl '--status'
$fine = $status -match 'Default Version|Default Distribution|no installed distributions'
$missing = $status -match 'Virtual Machine Platform|Optional Component|not enabled|not supported with your current machine|0x80370102|HYPERV_NOT_INSTALLED'
if ($missing -or ($LASTEXITCODE -ne 0 -and -not $fine)) {
    Say 'WSL needs two Windows features switched on. Doing that now; Windows asks for permission (a "Yes" prompt).'
    $out = Invoke-Wsl '--install', '--no-distribution'
    if ($LASTEXITCODE -ne 0) {
        Info (($out -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' ')
        Stop-Here 'Switching on WSL did not finish. Open PowerShell as administrator (right-click it, "Run as administrator") and paste the same command again.'
    }
    $changed.Add('Switched on WSL')
    Stop-Here @"
WSL is installed. Windows needs a restart to finish it.
Restart your PC, then open PowerShell and paste the same command again; it carries on from here.
"@
}

if ($status -match 'Default Version:\s*1') {
    Invoke-Wsl '--set-default-version', '2' | Out-Null
    $changed.Add('Set WSL 2 as the default version (it was WSL 1)')
}
Say 'WSL 2 is ready.'

# ---------------------------------------------------------------------------------------------
Step 'PowerShell 7 and fzf (the menu runs in PowerShell 7 and is drawn by fzf)'
$pwsh = Find-Pwsh
$fzf = Find-Fzf
$winget = $null
if (-not $pwsh -or -not $fzf) {
    $winget = Get-Winget
    if ($winget) { Info "winget $((Invoke-Program { & $winget --version }) | Select-Object -First 1)" }
}
if ($pwsh) { Say 'PowerShell 7: already installed' }
else {
    if ($winget) { Say 'Installing PowerShell 7 ...'; Install-WithWinget $winget 'Microsoft.PowerShell' 'PowerShell 7' | Out-Null; $pwsh = Find-Pwsh }
    if (-not $pwsh) {
        Say 'Installing PowerShell 7 from GitHub instead ...'
        try { Install-PwshMsi; $pwsh = Find-Pwsh } catch { Info "That did not work: $($_.Exception.Message)" }
    }
    if (-not $pwsh) {
        Stop-Here 'PowerShell 7 could not be installed. Install it from https://aka.ms/powershell-release?tag=stable (the .msi for Windows), then run this again.'
    }
    $changed.Add('Installed PowerShell 7')
}
if ($fzf) { Say 'fzf: already installed' }
elseif ($winget) {
    Say 'Installing fzf ...'
    if ((Install-WithWinget $winget 'junegunn.fzf' 'fzf') -and (Find-Fzf)) { $changed.Add('Installed fzf') }
    else { Say 'fzf could not be installed; the menu shows a numbered list instead, which works the same.' Yellow }
} else {
    Say 'winget is not available, so fzf is not installed; the menu shows a numbered list instead.' Yellow
    Info 'For the full menu later: install "App Installer" from the Microsoft Store, then: winget install junegunn.fzf'
}

# ---------------------------------------------------------------------------------------------
Step "hyprland-wsl itself, in $repo"
New-Item -ItemType Directory -Force $root | Out-Null
$git = if ($env:HYPRLAND_WSL_NO_GIT) { $null } else { Find-Exe 'git' @("$env:ProgramFiles\Git\cmd\git.exe") }
if ($env:HYPRLAND_WSL_SOURCE) {
    Say "Copying it from $env:HYPRLAND_WSL_SOURCE (HYPRLAND_WSL_SOURCE is set) ..."
    Invoke-Program { robocopy $env:HYPRLAND_WSL_SOURCE $repo /MIR /XD .git dev-log /XF claude-context.md /NFL /NDL /NJH /NJS /NP } | Out-Null
    if ($LASTEXITCODE -ge 8) { Stop-Here "Copying from $env:HYPRLAND_WSL_SOURCE did not work." }
    $changed.Add("Copied hyprland-wsl to $repo")
} elseif ($git -and (Test-Path (Join-Path $repo '.git'))) {
    Say 'Updating it ...'
    Invoke-Program { & $git -C $repo pull --ff-only --quiet } | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Here "Updating $repo with git did not work. Delete that folder and run this again." }
    $changed.Add("Updated hyprland-wsl in $repo")
} elseif ($git) {
    Say 'Downloading it with git ...'
    if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
    Invoke-Program { & $git clone --quiet --depth 1 "$github.git" $repo } | Out-Null
    if ($LASTEXITCODE -ne 0) { Stop-Here 'Downloading hyprland-wsl with git did not work. Check the internet connection and run this again.' }
    $changed.Add("Downloaded hyprland-wsl to $repo")
} else {
    Say 'Downloading it ...'
    $tmp = Join-Path $env:TEMP "hyprland-wsl-download-$PID"
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    try { Get-File "$github/archive/refs/heads/main.zip" (Join-Path $tmp 'main.zip') 'hyprland-wsl' }
    catch { Stop-Here 'Downloading hyprland-wsl did not work. Check the internet connection and run this again.' }
    Expand-Archive (Join-Path $tmp 'main.zip') $tmp
    $unpacked = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    if (Test-Path $repo) { Remove-Item -Recurse -Force $repo }
    Move-Item $unpacked $repo
    Remove-Item -Recurse -Force $tmp
    $changed.Add("Downloaded hyprland-wsl to $repo")
}

# ---------------------------------------------------------------------------------------------
Step 'The hyprland-wsl command and the Start menu entry'
$desktop = (Read-Host 'Also put a "Hyprland on WSL" shortcut on the desktop? (y/N)') -match '^y'
& (Join-Path $repo 'windows\install-command.ps1') -Desktop:$desktop | ForEach-Object { Say $_ }
$changed.Add("Added the hyprland-wsl command ($root\bin, on your user PATH)")
$changed.Add("Added ""Hyprland on WSL"" to the Start menu$(if ($desktop) { ' and the desktop' })")

# ---------------------------------------------------------------------------------------------
Step 'Done'
Say 'Changed on this PC:'
if ($changed.Count) { foreach ($c in $changed) { Say "  - $c" } } else { Say '  - nothing; everything was already in place' }
Say ''
Say 'From now on, open the menu with "Hyprland on WSL" in the Start menu, or by typing hyprland-wsl'
Say 'in any new terminal. Opening it now ...'
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
