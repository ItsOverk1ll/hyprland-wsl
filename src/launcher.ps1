# hyprland-wsl launcher: a menu of your WSL distros, styled like BetterHotkeys' menus (fzf, the
# current Omarchy theme). Enter starts the selected distro's Hyprland full screen.
#
#   Enter      start full screen          Ctrl+W   start in a window
#   Ctrl+T     stop the distro            Ctrl+D   remove (unregister) the distro
#   Ctrl+R     rescan every distro        Esc      close
#
# The top row, "+ New distro", creates one: Arch, CachyOS, Kali, Ubuntu or Mint with the account,
# hostname and so on asked for here (new-distro.ps1), or Omarchy, which asks in its own setup.
#
# What it knows about each distro (installed, user, versions) is read once by starting the
# distro and kept in %LOCALAPPDATA%\hyprland-wsl\distros.json; Ctrl+R refreshes it.
# Needs fzf (winget install junegunn.fzf).

$ErrorActionPreference = 'Stop'
# UTF-8 without BOM, otherwise the first line piped to fzf starts with U+FEFF
[Console]::OutputEncoding = $OutputEncoding = [Text.UTF8Encoding]::new($false)
$env:WSL_UTF8 = 1
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'remove-distro.ps1')
# Sent to each distro on stdin, so it works wherever the checkout is.
$infoScript = (Get-Content (Join-Path $PSScriptRoot 'distro-info.sh') -Raw) -replace "`r", ''
$dataDir = Join-Path $env:LOCALAPPDATA 'hyprland-wsl'
$cacheFile = Join-Path $dataDir 'distros.json'
$previewDir = Join-Path $env:TEMP 'hyprland-wsl-launcher'
New-Item -ItemType Directory -Force $dataDir, $previewDir | Out-Null

# Colours: BetterHotkeys' theme when it is installed, so the menus match; Hackerman otherwise.
$themeLib = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'AutoHotkey\theme-lib.ps1'
if (Test-Path $themeLib) {
    . $themeLib
    $theme = Get-CurrentTheme
} else {
    $theme = @{ accent = '#82FB9C'; selection = '#1F253A'; muted = '#2D3450'; dark_foreground = '#6A6E95'
                bright_foreground = '#DDF7FF'; red = '#50F872'; yellow = '#50F7D4' }
    function Get-Ansi([string]$hex) {
        $r, $g, $b = 1, 3, 5 | ForEach-Object { [Convert]::ToInt32($hex.Substring($_, 2), 16) }
        "$([char]27)[38;2;$r;$g;${b}m"
    }
    function Get-FzfColors($t) {
        "border:$($t.muted),label:$($t.accent),prompt:$($t.accent),pointer:$($t.accent),header:$($t.dark_foreground)," +
        "hl:$($t.accent),hl+:$($t.accent),info:$($t.dark_foreground),fg+:$($t.bright_foreground),bg+:$($t.selection),gutter:-1"
    }
}
$esc = [char]27
$accent = Get-Ansi $theme.accent; $dim = Get-Ansi $theme.dark_foreground; $bright = Get-Ansi $theme.bright_foreground
$warn = Get-Ansi $theme.yellow; $reset = "$esc[0m"

$fzf = Get-Command fzf -ErrorAction SilentlyContinue
$fzf = if ($fzf) { $fzf.Source } else {
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\junegunn.fzf*\fzf.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $fzf) {
    Write-Host "This menu needs fzf:  winget install junegunn.fzf"
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}
$fzfStyle = @('--ansi', '--layout=reverse', '--gutter= ', '--border=rounded', '--prompt=  ', '--pointer=>', '--info=inline-right',
    '--header-first', "--color=$(Get-FzfColors $theme)")

function Get-Distros {
    # wsl -l -v: "* Name  State  Version", the default marked with *
    (wsl.exe -l -v) | Select-Object -Skip 1 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        $default = $line.StartsWith('*')
        $parts = ($line.TrimStart('*').Trim()) -split '\s+'
        # Only table rows: with no distros installed, wsl prints a help text instead.
        if ($parts.Count -eq 3 -and $parts[2] -match '^\d+$') {
            [pscustomobject]@{ Name = $parts[0]; State = $parts[1]; Version = $parts[2]; Default = $default }
        }
    } | Where-Object { $_.Name -notmatch '^docker-desktop' }
}

function Read-Cache {
    if (Test-Path $cacheFile) { try { return Get-Content $cacheFile -Raw | ConvertFrom-Json -AsHashtable } catch {} }
    @{}
}

function Save-Cache($cache) { $cache | ConvertTo-Json -Depth 4 | Set-Content $cacheFile -Encoding utf8NoBOM }

# Starts the distro briefly to read what tools/distro-info.sh reports.
function Get-DistroInfo($name) {
    $info = @{ scanned = (Get-Date).ToString('yyyy-MM-dd HH:mm') }
    $out = $infoScript | wsl.exe -d $name -u root -- sh -s 2>$null
    foreach ($line in $out) {
        if ($line -match '^([a-z]+)=(.*)$') { $info[$Matches[1]] = $Matches[2].Trim() }
    }
    $info
}

function Update-Cache($cache, $distros, [switch]$All) {
    $todo = @($distros | Where-Object { $All -or -not $cache.Contains($_.Name) })
    if ($todo.Count) {
        Write-Host "`n  ${dim}Looking at $($todo.Count) distro$(if ($todo.Count -gt 1) { 's' }) ...$reset"
        # Each look starts the distro, which takes a few seconds; they run side by side.
        $getInfo = ${function:Get-DistroInfo}.ToString()
        $found = $todo | ForEach-Object -ThrottleLimit 6 -Parallel {
            $infoScript = $using:infoScript; $env:WSL_UTF8 = 1
            ${function:Get-DistroInfo} = $using:getInfo
            @{ name = $_.Name; info = Get-DistroInfo $_.Name }
        }
        foreach ($f in $found) { $cache[$f.name] = $f.info }
    }
    $gone = @($cache.Keys | Where-Object { $_ -notin $distros.Name })
    foreach ($g in $gone) { $cache.Remove($g) }
    if ($todo.Count -or $gone.Count -or $All) { Save-Cache $cache }
}

function Write-Preview($n, $d, $i) {
    $lines = @()
    if (-not $d) {
        $lines += "${accent}New distro$reset", '',
            'Install a new WSL distro with',
            'Hyprland: Arch Linux, CachyOS, Kali,',
            'Ubuntu, Linux Mint or Omarchy.', '',
            "${dim}You choose the name, account,$reset",
            "${dim}password and hostname next.$reset"
    } else {
        $state = if ($d.State -eq 'Running') { "${accent}running$reset" } else { "${dim}stopped$reset" }
        $lines += "$bright$($d.Name)$reset  $state$(if ($d.Default) { "  ${dim}(default)$reset" })", ''
        $lines += "${dim}System      $reset$($i.os)"
        if ($i.omarchy -and $i.os -ne 'Omarchy') { $lines += "${dim}Desktop     ${reset}Omarchy" }
        if ($i.hyprland) { $lines += "${dim}Hyprland    $reset$($i.hyprland)" }
        if ($i.installed) {
            $user = if ($i.setup) { "${warn}set up at first start$reset" } elseif ($i.user) { $i.user } else { '?' }
            $lines += "${dim}User        $reset$user"
            $render = if ($i.gpu -and $i.mesa -and [int]($i.mesa -split '\.')[0] -ge 26) { "GPU ${dim}(Mesa $($i.mesa))$reset" }
                      elseif ($i.mesa) { "CPU ${dim}(Mesa $($i.mesa) < 26)$reset" } else { 'CPU' }
            $lines += "${dim}Renders on  $reset$render"
        } else {
            $lines += '', "${warn}hyprland-wsl is not installed.$reset"
            if ($i.family) { $lines += "${dim}Enter installs it.$reset" }
            else { $lines += "${dim}This distro is not supported yet.$reset" }
        }
        $lines += '', "${dim}As of $($i.scanned); Ctrl+R rescans.$reset"
    }
    Set-Content (Join-Path $previewDir "$n.txt") ($lines -join "`n") -Encoding utf8NoBOM
}

function Start-Distro($d, $info, [switch]$Windowed) {
    $launch = Join-Path $repo 'windows\hyprland-wsl.ps1'
    $argv = @('-NoLogo', '-NoProfile', '-File', $launch, '-Distro', $d.Name)
    if ($Windowed) { $argv += '-Windowed' }
    if ($info.setup) {
        # The first start runs a setup that needs this terminal.
        Clear-Host
        & pwsh @argv
        return
    }
    Start-Process pwsh -ArgumentList $argv -WindowStyle Hidden
    Write-Host "  ${accent}Starting $($d.Name) ...$reset"
    Start-Sleep -Milliseconds 700
    exit 0
}

function Install-HyprlandWsl($d, $info) {
    Clear-Host
    Write-Host "`n  ${accent}Install hyprland-wsl into $($d.Name)?$reset  ${dim}(y/N)$reset " -NoNewline
    if ([Console]::ReadLine() -notmatch '^y') { return }
    wsl.exe -d $d.Name -u root -- bash "$(Get-RepoWslPath)/install.sh"
    Write-Host "`n  ${dim}Press Enter to go back$reset"; [Console]::ReadLine() | Out-Null
}

# A name not taken yet: base, base2, base3, ...
function Get-FreeName($base, $distros) {
    $n = 1; while ("$base$(if ($n -gt 1) { $n })" -in $distros.Name) { $n++ }
    "$base$(if ($n -gt 1) { $n })"
}

# One line of the form: the label, the default in brackets, Enter keeps it. Asks again until
# $valid (a regex) matches.
function Read-Field($label, $default, $valid, $hint) {
    while ($true) {
        Write-Host "  ${accent}$($label.PadRight(10))$reset$(if ($default) { " ${dim}[$default]$reset" })${accent} >$reset " -NoNewline
        $v = [Console]::ReadLine().Trim()
        if (-not $v) { $v = $default }
        if ($v -and (-not $valid -or $v -cmatch $valid)) { return $v }
        Write-Host "  ${warn}$hint$reset"
    }
}

function Read-YesNo($label, [bool]$default) {
    $v = Read-Field $label $(if ($default) { 'Y/n' } else { 'y/N' }) $null ''
    if ($v -in 'Y/n', 'y/N') { return $default }
    $v -match '^y'
}

$newDistros = [ordered]@{
    arch    = @('Arch Linux',      'From WSL''s own catalogue. Rolling', 'release, the newest Hyprland.')
    cachyos = @('CachyOS',         'Arch-based, with optimised packages.', 'Downloaded from its Docker image.')
    kali    = @('Kali Linux',      'From WSL''s own catalogue. Debian-', 'based, rolling.')
    ubuntu  = @('Ubuntu 26.04',    'From WSL''s own catalogue. An older', 'Hyprland (0.53) than the others.')
    mint    = @('Linux Mint 22.3', 'From its Docker image. Hyprland', 'comes from a third-party PPA.')
    omarchy = @('Omarchy',         'Arch with Omarchy, the desktop by', 'DHH. Asks for its account and', 'the rest in its own setup screens.')
}

# Sets $script:made to the new distro's name when it should be started. Called as a statement,
# not for its output: capturing it would take the terminal away from install.sh's questions.
function New-Distro($distros) {
    $script:made = $null
    $rows = foreach ($k in $newDistros.Keys) {
        $t = $newDistros[$k]
        $lines = @("$accent$($t[0])$reset", '') + $t[1..($t.Count - 1)]
        Set-Content (Join-Path $previewDir "new-$k.txt") ($lines -join "`n") -Encoding utf8NoBOM
        "$bright$($t[0])$reset`tnew-$k"
    }
    Push-Location $previewDir
    try {
        $pick = $rows | & $fzf @fzfStyle --delimiter="`t" --with-nth=1 `
            --preview='type {2}.txt' --preview-window='right,50%,border-left,wrap' `
            --border-label=' New distro ' --header='Enter choose · Esc back'
    } finally { Pop-Location }
    if (-not $pick) { return }
    $kind = ($pick -split "`t")[-1] -replace '^new-', ''
    $title = $newDistros[$kind][0]
    Clear-Host

    if ($kind -eq 'omarchy') {
        $name = Get-FreeName 'omarchy' $distros
        Write-Host "`n  ${accent}New Omarchy instance '$name'$reset ${dim}in $distroRoot\$name$reset`n"
        & pwsh -NoLogo -NoProfile -File (Join-Path $repo 'windows\install-omarchy.ps1') -Name $name -Location "$distroRoot\$name"
        return
    }

    Write-Host "`n  ${accent}New $title$reset  ${dim}Enter keeps the value in brackets. Ctrl+C closes the menu.$reset`n"
    $name = Read-Field 'Name' (Get-FreeName $kind $distros) '^[A-Za-z0-9._-]+$' 'Letters, digits, dots, dashes and underscores.'
    if ($name -in $distros.Name) { Write-Host "  ${warn}'$name' exists already.$reset"; Start-Sleep 2; return }
    $folder = Read-Field 'Folder' "$distroRoot\$name" $null ''
    $me = ($env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '')
    if ($me -notmatch '^[a-z_]') { $me = 'user' }
    $user = Read-Field 'User' $me '^(?!root$)[a-z_][a-z0-9_-]{0,31}$' 'Lower case letters, digits, - and _, starting with a letter.'
    while ($true) {
        Write-Host "  ${accent}$('Password'.PadRight(10))$reset${accent} >$reset " -NoNewline
        $pw = Read-Host -AsSecureString
        Write-Host "  ${accent}$('Again'.PadRight(10))$reset${accent} >$reset " -NoNewline
        $pw2 = Read-Host -AsSecureString
        $a = [Net.NetworkCredential]::new('', $pw).Password; $b = [Net.NetworkCredential]::new('', $pw2).Password
        if (-not $a) { Write-Host "  ${warn}The password cannot be empty.$reset"; continue }
        if ($a -cne $b) { Write-Host "  ${warn}They differ; once more.$reset"; continue }
        break
    }
    $hostname = Read-Field 'Hostname' ($name -replace '[^A-Za-z0-9-]', '-') '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$' 'Letters, digits and dashes.'
    $mod = (Read-Field 'Main key' 'SUPER' '^(?i)(super|alt)$' 'SUPER (the Windows key) or ALT.').ToUpper()
    $default = Read-YesNo 'Default' $false
    $ppa = $false
    if ($kind -eq 'mint') {
        Write-Host "  ${dim}Mint has no Hyprland package: it comes from ppa:cppiber/hyprland, and a newer$reset"
        Write-Host "  ${dim}Mesa (for the GPU) from ppa:kisak/kisak-mesa. Neither is part of Mint.$reset"
        $ppa = Read-YesNo 'Use PPAs' $true
        if (-not $ppa) { Write-Host "  ${warn}Without them install.sh asks again, and Hyprland cannot be installed.$reset" }
    }
    $start = Read-YesNo 'Start it' $true

    Write-Host "`n  ${bright}$title '$name'$reset ${dim}in $folder, user $user, hostname $hostname, main key $mod$(if ($default) { ', default distro' })$reset"
    if (-not (Read-YesNo 'Create' $true)) { return }

    $params = @{ Distro = $kind; Name = $name; Location = $folder; User = $user; Password = $pw
                 Hostname = $hostname; Mod = $mod; SetDefault = $default; AllowPpa = $ppa }
    try {
        & (Join-Path $PSScriptRoot 'new-distro.ps1') @params
    } catch {
        Write-Host "`n  ${warn}$($_.Exception.Message)$reset"
        Write-Host "`n  ${dim}Press Enter to go back$reset"; [Console]::ReadLine() | Out-Null
        return
    }
    if ($start) { $script:made = $name; return }
    Write-Host "`n  ${dim}Press Enter to go back$reset"; [Console]::ReadLine() | Out-Null
}

function Remove-Distro($d) {
    Clear-Host
    $l = Get-DistroLeftovers $d.Name
    Write-Host "`n  ${warn}Remove $($d.Name)?$reset  ${dim}This deletes for good:$reset"
    foreach ($w in Format-Leftovers $l) { Write-Host "  ${dim}- $w$reset" }
    Write-Host "`n  ${dim}Type the name to confirm, or Enter to keep it.$reset`n"
    Write-Host "  ${accent}Name$reset${accent} >$reset " -NoNewline
    if ([Console]::ReadLine().Trim() -cne $d.Name) { return $false }
    try { Remove-DistroCompletely $l } catch { Write-Host "  ${warn}$($_.Exception.Message)$reset"; Start-Sleep 3 }
    Start-Sleep 1
    $true
}

$cache = Read-Cache
$distros = @(Get-Distros)
Update-Cache $cache $distros

while ($true) {
    $distros = @(Get-Distros)
    Clear-Host
    $rows = @("$accent+ New distro$reset`t0")
    Write-Preview 0 $null $null
    $i = 1
    foreach ($d in $distros) {
        $info = if ($cache.Contains($d.Name)) { $cache[$d.Name] } else { @{} }
        $dot = if ($d.State -eq 'Running') { "$accent●$reset" } else { "$dim○$reset" }
        $what = if ($info.omarchy) { 'Omarchy' } elseif ($info.os) { ($info.os -replace ' GNU/Linux| LTS|\(.*\)', '').Trim() } else { '' }
        # padded before colouring: the escape codes would count towards the width
        $name = if ($info.installed) { "$bright{0,-16}$reset" -f $d.Name } else { "$dim{0,-16}$reset" -f $d.Name }
        $what = "$dim{0,-17}$reset" -f $what
        $note = if ($info.setup) { "${warn}first-start setup$reset" } elseif ($info.installed) { "$dim$($info.hyprland)$reset" } else { "${dim}not set up$reset" }
        $rows += ("{0} {1} {2} {3}`t{4}" -f $dot, $name, $what, $note, $i)
        Write-Preview $i $d $info
        $i++
    }

    Push-Location $previewDir
    try {
        $out = $rows | & $fzf @fzfStyle --delimiter="`t" --with-nth=1 --expect='ctrl-w,ctrl-t,ctrl-d,ctrl-r' `
            --preview='type {2}.txt' --preview-window='right,40%,border-left,wrap' `
            --border-label=' Hyprland on WSL ' `
            --header="Enter start · Ctrl+W windowed · Ctrl+T stop`nCtrl+D remove · Ctrl+R rescan · Esc close"
    } finally { Pop-Location }
    if (-not $out) { exit 0 }
    $key, $row = @($out)
    if ($key -eq 'ctrl-r') { Clear-Host; Update-Cache $cache $distros -All; continue }
    if (-not $row) { continue }
    $index = [int]($row -split "`t")[-1]
    if ($index -eq 0) {
        if ($key) { continue }
        New-Distro $distros
        $distros = @(Get-Distros)
        Update-Cache $cache $distros
        if ($made) { Start-Distro ($distros | Where-Object Name -eq $made) $cache[$made] }
        continue
    }

    $d = $distros[$index - 1]
    $info = $cache[$d.Name]
    if ($key -eq 'ctrl-t') { wsl.exe -t $d.Name | Out-Null; continue }
    if ($key -eq 'ctrl-d') { if (Remove-Distro $d) { $cache.Remove($d.Name); Save-Cache $cache }; continue }
    if (-not $info.installed) {
        if ($info.family) { Install-HyprlandWsl $d $info; $cache[$d.Name] = Get-DistroInfo $d.Name; Save-Cache $cache }
        continue
    }
    Start-Distro $d $info -Windowed:($key -eq 'ctrl-w')
    # Back from a first-start setup: what the distro reports has changed.
    $cache[$d.Name] = Get-DistroInfo $d.Name; Save-Cache $cache
}
