# Package abc-bank-pm-os for Claude Cowork upload (.zip and .plugin)
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$staging = Join-Path $env:TEMP "abc-bank-pm-os-plugin"
$dist = Join-Path $root "dist"
$zipPath = Join-Path $dist "abc-bank-pm-os.zip"
$pluginPath = Join-Path $dist "abc-bank-pm-os.plugin"

Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging -Force | Out-Null
New-Item -ItemType Directory -Path $dist -Force | Out-Null

Copy-Item (Join-Path $root ".claude-plugin") (Join-Path $staging ".claude-plugin") -Recurse -Force
Copy-Item (Join-Path $root ".claude\skills") (Join-Path $staging ".claude\skills") -Recurse -Force
Copy-Item (Join-Path $root ".claude\agents") (Join-Path $staging ".claude\agents") -Recurse -Force
Copy-Item (Join-Path $root ".claude\hooks") (Join-Path $staging ".claude\hooks") -Recurse -Force

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $zipPath -Force
Copy-Item $zipPath $pluginPath -Force

Remove-Item $staging -Recurse -Force

Write-Host "Packaged plugin:"
Write-Host "  $zipPath"
Write-Host "  $pluginPath"
Write-Host ""
Write-Host "Upload abc-bank-pm-os.zip in Cowork -> Customize -> Personal plugins -> Upload plugin"
