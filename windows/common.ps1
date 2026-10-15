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

# ---- Distros made here -------------------------------------------------------------------------
# new-distro.ps1 and install-omarchy.ps1 note the distros they create, so removing one that was
# made elsewhere (and may hold someone's own work) gets an extra warning.
$createdFile = Join-Path $dataRoot 'created.json'
function Get-CreatedDistros {
    if (Test-Path $createdFile) { try { return @(Get-Content $createdFile -Raw | ConvertFrom-Json) } catch {} }
    @()
}
function Add-CreatedDistro([string] $distro) {
    New-Item -ItemType Directory -Force $dataRoot | Out-Null
    $list = @(Get-CreatedDistros | Where-Object { $_ -ne $distro }) + $distro
    ConvertTo-Json -InputObject @($list) | Set-Content $createdFile -Encoding Ascii
}
function Remove-CreatedDistro([string] $distro) {
    if (-not (Test-Path $createdFile)) { return }
    ConvertTo-Json -InputObject @(Get-CreatedDistros | Where-Object { $_ -ne $distro }) | Set-Content $createdFile -Encoding Ascii
}

# ---- Logs --------------------------------------------------------------------------------------
# Long installs keep their full output here, for bug reports.
$logDir = Join-Path $dataRoot 'logs'
function New-LogFile([string] $what) {
    New-Item -ItemType Directory -Force $logDir | Out-Null
    Join-Path $logDir ("{0}-{1:yyyyMMdd-HHmmss}.log" -f $what, (Get-Date))
}

# ---- Start menu shortcuts ----------------------------------------------------------------------
# hyprland-wsl's shortcuts are told apart from others by their description.
$startMenu = [Environment]::GetFolderPath('Programs')
$menuShortcutNote = 'hyprland-wsl: the menu'
function Get-DistroShortcutNote([string] $distro) { "hyprland-wsl distro: $distro" }

function Get-PwshPath {
    $c = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $p = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    if (Test-Path $p) { return $p }
    $null
}

function New-Shortcut([string] $path, [string] $target, [string] $arguments, [string] $note, [string] $icon) {
    $shell = New-Object -ComObject WScript.Shell
    $l = $shell.CreateShortcut($path)
    $l.TargetPath = $target
    $l.Arguments = $arguments
    $l.Description = $note
    $l.WorkingDirectory = $env:USERPROFILE
    if ($icon) { $l.IconLocation = $icon }
    $l.Save()
}

# The .lnk files in the Start menu (and on the desktop) that carry this description.
function Find-Shortcuts([string] $note) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($dir in $startMenu, [Environment]::GetFolderPath('Desktop')) {
        Get-ChildItem $dir -Filter *.lnk -ErrorAction SilentlyContinue |
            Where-Object { $shell.CreateShortcut($_.FullName).Description -eq $note } |
            ForEach-Object { $_.FullName }
    }
}

# A Start menu entry that starts the distro's Hyprland full screen, e.g. "Arch Linux (myarch)".
function Set-DistroShortcut([string] $distro, [string] $title) {
    $pwsh = Get-PwshPath
    $target = if ($pwsh) { $pwsh } else { 'powershell.exe' }
    $note = Get-DistroShortcutNote $distro
    Find-Shortcuts $note | Remove-Item -ErrorAction SilentlyContinue
    # WSL keeps an icon for distros it installed from its catalogue.
    $key = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue |
        Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq $distro } | Select-Object -First 1
    $base = if ($key) { (Get-ItemProperty $key.PSPath).BasePath -replace '^\\\\\?\\', '' }
    $icon = if ($base -and (Test-Path (Join-Path $base 'shortcut.ico'))) { Join-Path $base 'shortcut.ico' } else { "$env:SystemRoot\System32\wsl.exe,0" }
    $file = Join-Path $startMenu (($title -replace '[\\/:*?"<>|]', '-') + '.lnk')
    New-Shortcut $file $target "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\hyprland-wsl.ps1`" -Distro $distro" $note $icon
    $file
}

# ---- The keyboard card -------------------------------------------------------------------------
# Shown in the terminal before a distro's first session: how to get out of full screen, open a
# terminal, end the session, and which key is the main one. Once per distro; the menu shows it
# again on request (Ctrl+K).
$keysSeenFile = Join-Path $dataRoot 'keys-seen.json'
function Test-KeysSeen([string] $distro) {
    if (-not (Test-Path $keysSeenFile)) { return $false }
    try { return $distro -in @(Get-Content $keysSeenFile -Raw | ConvertFrom-Json) } catch { return $false }
}
function Set-KeysSeen([string] $distro) {
    New-Item -ItemType Directory -Force $dataRoot | Out-Null
    $seen = @()
    if (Test-Path $keysSeenFile) { try { $seen = @(Get-Content $keysSeenFile -Raw | ConvertFrom-Json) } catch {} }
    ConvertTo-Json -InputObject @(@($seen | Where-Object { $_ -ne $distro }) + $distro) | Set-Content $keysSeenFile -Encoding Ascii
}

# What the card needs from the distro (its main key, whether it is Omarchy), from distro-info.sh.
function Get-KeyInfo([string] $distro) {
    $info = @{}
    $script = (Get-Content (Join-Path $repo 'tools\distro-info.sh') -Raw) -replace "`r", ''
    $wslArgs = @(); if ($distro) { $wslArgs += '-d', $distro }
    $out = $script | & wsl.exe @wslArgs -u root -- sh -s 2>$null
    foreach ($line in $out) { if ($line -match '^([a-z]+)=(.*)$') { $info[$Matches[1]] = $Matches[2].Trim() } }
    $info
}

function Show-KeyCard([string] $distro, [string] $mod, [bool] $omarchy, [switch] $Again) {
    $main = if ($omarchy -or $mod -eq 'SUPER') { 'Win' } else { 'Alt' }
    $name = if ($distro) { $distro } else { 'your distro' }
    $row = { param($k, $v) Write-Host ('  {0,-17}' -f $k) -ForegroundColor Cyan -NoNewline; Write-Host $v }
    Write-Host ''
    Write-Host "  Keyboard basics for $name" -ForegroundColor Green
    Write-Host ''
    & $row 'Main key' $(if ($main -eq 'Win') { 'the Windows key, called SUPER in Hyprland' } else { 'Alt (the Windows key stays with Windows)' })
    & $row 'Full screen' 'Ctrl+Alt+Enter leaves full screen, to get to Windows; press it again to go back'
    if ($omarchy) {
        & $row 'Terminal' 'Win+Enter'
        & $row 'Apps and menu' 'Win+Space opens Omarchy''s menu; Win+K lists every key'
        & $row 'Close a window' 'Win+W'
        & $row 'End the session' 'Power Off in Omarchy''s menu (shuts the distro down), or close the viewer'
    } else {
        & $row 'Terminal' "$main+Q"
        & $row 'Close a window' "$main+C"
        & $row 'Workspaces' "$main+1 to $main+0"
        & $row 'End the session' "$main+M, or close the viewer window"
    }
    Write-Host ''
    if (-not $Again) { Write-Host '  This card shows once per distro; the hyprland-wsl menu shows it again with Ctrl+K.' -ForegroundColor DarkGray }
    Read-Host "  Press Enter to $(if ($Again) { 'go back' } else { 'start' })" | Out-Null
}
