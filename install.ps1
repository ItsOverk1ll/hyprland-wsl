# Installs the hyprland-wsl launcher: a menu of your WSL distros that starts, creates and removes
# them, opened with "hyprland-wsl" in any terminal or Win+Shift+H. From PowerShell:
#
#   irm https://raw.githubusercontent.com/ItsOverk1ll/hyprland-wsl/Launcher/install.ps1 | iex
#
# Or from a clone of this branch, with options:
#
#   .\install.ps1                         download hyprland-wsl itself (the main branch)
#   .\install.ps1 -Repo P:\hyprland-wsl   use your own clone of the main branch instead
#   .\install.ps1 -NoHotkey               leave BetterHotkeys alone
#
# Running it again updates everything. It runs in Windows PowerShell 5.1 and PowerShell 7.

param(
    [string] $Repo,
    [switch] $NoHotkey
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072   # TLS 1.2
$github = 'https://github.com/ItsOverk1ll/hyprland-wsl'
$root = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$dest = Join-Path $root 'launcher'
$bin = Join-Path $root 'bin'
New-Item -ItemType Directory -Force $root | Out-Null

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Green }

# A branch of the repository as a folder, without git.
function Get-Branch([string] $branch) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "hyprland-wsl-$branch-$PID"
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'branch.zip'
    Invoke-WebRequest -UseBasicParsing "$github/archive/refs/heads/$branch.zip" -OutFile $zip
    Expand-Archive $zip $tmp
    (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
}

Step 'The launcher'
$from = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'src\launcher.ps1'))) {
    Join-Path $PSScriptRoot 'src'
} else {
    Write-Host 'Downloading the Launcher branch ...'
    Join-Path (Get-Branch 'Launcher') 'src'
}
Remove-Item -Recurse -Force $dest -ErrorAction SilentlyContinue
New-Item -ItemType Directory $dest | Out-Null
Copy-Item (Join-Path $from '*') $dest -Recurse
if ($from -like "$([IO.Path]::GetTempPath())*") { Remove-Item -Recurse -Force (Split-Path (Split-Path $from)) }
Write-Host "in $dest"

Step 'hyprland-wsl itself'
if ($Repo) {
    $Repo = (Resolve-Path $Repo).Path
    if (-not (Test-Path (Join-Path $Repo 'install.sh'))) { throw "$Repo is not a clone of hyprland-wsl's main branch (no install.sh)." }
    $repoPath = $Repo
    Write-Host "using your clone, $repoPath"
} else {
    Write-Host 'Downloading the main branch ...'
    $repoPath = Join-Path $root 'repo'
    $main = Get-Branch 'main'
    Remove-Item -Recurse -Force $repoPath -ErrorAction SilentlyContinue
    Move-Item $main $repoPath
    Remove-Item -Recurse -Force (Split-Path $main)
    Write-Host "in $repoPath"
}
@{ repo = $repoPath } | ConvertTo-Json | Set-Content (Join-Path $root 'settings.json') -Encoding Ascii

Step 'What the menu needs'
# PowerShell 7 runs the menu; fzf draws it.
foreach ($p in @(@{ Cmd = 'pwsh'; Id = 'Microsoft.PowerShell' }, @{ Cmd = 'fzf'; Id = 'junegunn.fzf' })) {
    $found = Get-Command $p.Cmd -ErrorAction SilentlyContinue
    if (-not $found -and $p.Cmd -eq 'fzf') {
        $found = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe" -ErrorAction SilentlyContinue
    }
    if ($found) { Write-Host "$($p.Cmd): already there"; continue }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "$($p.Cmd) is missing and winget is not available; install $($p.Id) yourself." -ForegroundColor Yellow
        continue
    }
    Write-Host "installing $($p.Id) with winget ..."
    winget install --id $p.Id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
}

Step 'The hyprland-wsl command'
# Without arguments it opens the menu; with them it starts a distro (hyprland-wsl -Distro NAME).
New-Item -ItemType Directory -Force $bin | Out-Null
$shim = @(
    '@echo off'
    'rem hyprland-wsl on Windows: the menu without arguments, a session with them (-Distro NAME ...).'
    'rem Written by the hyprland-wsl launcher''s install.ps1.'
    'setlocal'
    'set "PS=powershell"'
    'where pwsh >nul 2>nul && set "PS=pwsh"'
    'if "%~1"=="" goto menu'
    "%PS% -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$repoPath\windows\hyprland-wsl.ps1`" %*"
    'exit /b %errorlevel%'
    ':menu'
    'if not "%PS%"=="pwsh" echo The menu needs PowerShell 7: winget install Microsoft.PowerShell & exit /b 1'
    "pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$dest\launcher.ps1`""
)
Set-Content (Join-Path $bin 'hyprland-wsl.cmd') $shim -Encoding Ascii
# The user PATH, read without expanding %VARIABLES% so they survive being written back.
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$path = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$entries = @($path -split ';' | Where-Object { $_ })
if (-not ($entries | Where-Object { $_.TrimEnd('\') -ieq $bin })) {
    $key.SetValue('Path', (($entries + $bin) -join ';'), [Microsoft.Win32.RegistryValueKind]::ExpandString)
    # Tells Explorer and new terminals that the environment changed.
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', '1', 'User')
    [Environment]::SetEnvironmentVariable('HYPRLAND_WSL_PATH_CHANGED', $null, 'User')
    Write-Host "added $bin to your PATH"
}
if (($env:Path -split ';') -notcontains $bin) { $env:Path += ";$bin" }

if (-not $NoHotkey) {
    Step 'Win+Shift+H'
    & (Join-Path $dest 'install-hotkey.ps1')
}

Step 'Done'
Write-Host 'Open the menu by typing this in a new terminal:  hyprland-wsl'
