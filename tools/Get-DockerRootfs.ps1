# Downloads the layers of a Docker Hub image (linux/amd64) so its root filesystem can be
# imported into WSL with "wsl --import". No Docker needed.
param(
    [Parameter(Mandatory)] [string] $Image,   # e.g. cachyos/cachyos
    [string] $Tag = 'latest',
    [Parameter(Mandatory)] [string] $OutDir
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
New-Item -ItemType Directory -Force $OutDir | Out-Null

$token = (Invoke-RestMethod "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${Image}:pull").token
$auth = @{ Authorization = "Bearer $token" }
$accept = 'application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, ' +
          'application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
$base = "https://registry-1.docker.io/v2/$Image"

$m = Invoke-RestMethod "$base/manifests/$Tag" -Headers ($auth + @{ Accept = $accept })
if ($m.manifests) {
    $d = ($m.manifests | Where-Object { $_.platform.architecture -eq 'amd64' -and $_.platform.os -eq 'linux' } | Select-Object -First 1).digest
    $m = Invoke-RestMethod "$base/manifests/$d" -Headers ($auth + @{ Accept = $accept })
}
$i = 0
foreach ($layer in $m.layers) {
    $i++
    $file = Join-Path $OutDir ('layer{0:d2}.tar.gz' -f $i)
    "layer $i  $([math]::Round($layer.size / 1MB, 1)) MB  $($layer.mediaType)"
    curl.exe -fsSL -H "Authorization: Bearer $token" "$base/blobs/$($layer.digest)" -o $file
    if ($LASTEXITCODE) { throw "download of layer $i failed" }
}
"layers: $i"
