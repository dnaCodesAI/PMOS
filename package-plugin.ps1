# Package abc-bank-pm-os for Claude Cowork upload (.zip and .plugin)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-PluginZip {
    param(
        [string]$SourceDir,
        [string]$DestinationZip
    )

    if (Test-Path $DestinationZip) {
        Remove-Item $DestinationZip -Force
    }

    $zip = [System.IO.Compression.ZipFile]::Open($DestinationZip, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
            $relative = $_.FullName.Substring($SourceDir.Length).TrimStart('\', '/').Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $relative) | Out-Null
        }
    }
    finally {
        $zip.Dispose()
    }
}

$root = $PSScriptRoot
$staging = Join-Path $env:TEMP "abc-bank-pm-os-plugin"
$dist = Join-Path $root "dist"
$zipPath = Join-Path $dist "abc-bank-pm-os.zip"
$pluginPath = Join-Path $dist "abc-bank-pm-os.plugin"

Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $staging -Force | Out-Null
New-Item -ItemType Directory -Path $dist -Force | Out-Null

# Standard plugin layout: skills/, agents/, hooks/ at package root
Copy-Item (Join-Path $root ".claude-plugin") (Join-Path $staging ".claude-plugin") -Recurse -Force
Copy-Item (Join-Path $root ".claude\skills") (Join-Path $staging "skills") -Recurse -Force
Copy-Item (Join-Path $root ".claude\agents") (Join-Path $staging "agents") -Recurse -Force
Copy-Item (Join-Path $root ".claude\hooks") (Join-Path $staging "hooks") -Recurse -Force

New-PluginZip -SourceDir $staging -DestinationZip $zipPath
Copy-Item $zipPath $pluginPath -Force

Remove-Item $staging -Recurse -Force

Write-Host "Packaged plugin (forward-slash paths):"
Write-Host "  $zipPath"
Write-Host "  $pluginPath"
Write-Host ""
Write-Host "Zip entries:"
[System.IO.Compression.ZipFile]::OpenRead($zipPath).Entries | ForEach-Object { Write-Host "  $($_.FullName)" }
Write-Host ""
Write-Host "Upload abc-bank-pm-os.zip in Cowork -> Customize -> Personal plugins -> Upload plugin"
