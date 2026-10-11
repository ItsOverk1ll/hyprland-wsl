# Starts Hyprland in a WSL distro and shows it with a VNC viewer that runs on Windows itself.
#
# Unlike the viewer window that "hyprland-wsl" opens from inside WSL, a Windows viewer can
# capture the whole keyboard while it is full screen, including the Windows key and Alt+Tab.
# That makes SUPER usable as Hyprland's main modifier.
#
#   .\hyprland-wsl.ps1 -Distro Ubuntu-26.04            full screen, keyboard captured
#   .\hyprland-wsl.ps1 -Distro archlinux -Windowed     in a window
#
# Leaving full screen or the session: press F8 in the viewer for its menu.
# Closing the viewer ends the Hyprland session.

#
# Full screen on a scaled display (for example 3840x2160 at 150 %): by default Hyprland renders
# at the size Windows calls 100 % (2560x1440 in that example) and Windows enlarges the picture
# to fill the screen. Hyprland renders on the CPU, and the full resolution is too many pixels
# for it to stay smooth. -Native renders every pixel instead: sharper, and much slower.

param(
    [string] $Distro,                  # default: the default WSL distro
    [string] $Size,                    # WIDTHxHEIGHT; default: see above (1600x900 with -Windowed)
    [double] $Scale = 0,               # Hyprland's scale; default 1, or the Windows scale with -Native
    [int]    $Port = 5900,
    [switch] $Windowed,
    [switch] $Native                   # full screen at the display's real resolution
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:WSL_UTF8 = 1

function Get-Viewer {
    # An installed TigerVNC, a copy fetched earlier, or a fresh download of the standalone viewer.
    $own = Join-Path $env:LOCALAPPDATA 'hyprland-wsl\vncviewer64.exe'
    foreach ($p in "$env:ProgramFiles\TigerVNC\vncviewer.exe", $own) {
        if (Test-Path $p) { return $p }
    }
    $version = '1.16.2'
    Write-Host "Downloading the TigerVNC viewer $version ..."
    New-Item -ItemType Directory -Force (Split-Path $own) | Out-Null
    $tmp = "$own.download"
    curl.exe -fsSL "https://sourceforge.net/projects/tigervnc/files/stable/$version/vncviewer64-$version.exe/download" -o $tmp
    if ($LASTEXITCODE) { throw 'Could not download the TigerVNC viewer. Install TigerVNC yourself and run this again.' }
    if ((Get-AuthenticodeSignature $tmp).Status -ne 'Valid') {
        Remove-Item $tmp
        throw 'The downloaded viewer does not carry a valid signature; not using it.'
    }
    Move-Item $tmp $own -Force
    return $own
}

function Test-Vnc {
    $c = New-Object Net.Sockets.TcpClient
    try {
        $c.Connect('127.0.0.1', $Port)
        $s = $c.GetStream(); $s.ReadTimeout = 2000
        $b = New-Object byte[] 12
        return ($s.Read($b, 0, 12) -gt 0 -and [Text.Encoding]::ASCII.GetString($b, 0, 3) -eq 'RFB')
    } catch { return $false } finally { $c.Close() }
}

$dpi = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI
$winScale = if ($dpi) { [math]::Round($dpi / 96 * 4) / 4 } else { 1 }
if (-not $Size) {
    if ($Windowed) { $Size = '1600x900' }
    else {
        $v = Get-CimInstance Win32_VideoController | Where-Object CurrentHorizontalResolution | Select-Object -First 1
        $w = $v.CurrentHorizontalResolution; $h = $v.CurrentVerticalResolution
        if (-not $Native) { $w = [int]($w / $winScale); $h = [int]($h / $winScale) }
        $Size = '{0}x{1}' -f $w, $h
    }
}
if ($Scale -le 0) { $Scale = if ($Native -and -not $Windowed) { $winScale } else { 1 } }

# TigerVNC's viewer leaves display scaling to Windows, which then enlarges its picture. That is
# what the default mode relies on. With -Native the viewer is told to use real pixels instead.
$env:__COMPAT_LAYER = if ($Native) { 'HighDpiAware' } else { 'DpiUnaware' }
$scaleText = $Scale.ToString([Globalization.CultureInfo]::InvariantCulture)

$viewer = Get-Viewer
$wsl = @()
if ($Distro) { $wsl += '-d', $Distro }
$wsl += '-u', 'root', '--'

if (Test-Vnc) { throw "Something already answers on port $Port. Stop that session or pick another -Port." }

Write-Host "Starting Hyprland at $Size, scale $scaleText ..."
$session = Start-Process wsl.exe -ArgumentList ($wsl + 'hyprland-wsl', $Size, '--scale', $scaleText, '--port', $Port, '--no-viewer') `
    -WindowStyle Hidden -PassThru
try {
    $up = $false
    foreach ($i in 1..60) {
        if (Test-Vnc) { $up = $true; break }
        if ($session.HasExited) { break }
        Start-Sleep -Milliseconds 500
    }
    if (-not $up) { throw "Hyprland did not come up. Run 'hyprland-wsl --no-viewer' inside the distro to see why." }

    $viewerArgs = @('-RemoteResize=0', '-FullscreenSystemKeys=1')
    if (-not $Windowed) { $viewerArgs += '-FullScreen=1' }
    $viewerArgs += "127.0.0.1::$Port"
    Start-Process $viewer -ArgumentList $viewerArgs -Wait
}
finally {
    # Ending Hyprland makes the launcher inside WSL shut the rest down.
    & wsl.exe @wsl pkill -x Hyprland 2>$null | Out-Null
}
