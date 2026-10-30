$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root 'artifacts/dual-edition'
$plugin = Join-Path $root 'wordpress/wood-panel-app-manager'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$archivePath = Join-Path $destination 'wood-panel-app-manager.zip'
$stream = [IO.File]::Create($archivePath)
$archive = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $plugin -Recurse -File) {
        $relative = $file.FullName.Substring($plugin.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "wood-panel-app-manager/$relative") | Out-Null
    }
} finally {
    $archive.Dispose()
    $stream.Dispose()
}
Copy-Item -LiteralPath (Join-Path $root 'build/app/outputs/flutter-apk/app-debug.apk') -Destination (Join-Path $destination 'wood-panel-dual-edition-debug.apk')
Copy-Item -LiteralPath (Join-Path $root 'docs/dual-edition-deployment.md') -Destination $destination
Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath, (Join-Path $destination 'wood-panel-dual-edition-debug.apk') |
    Select-Object Algorithm, Hash, Path | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'checksums.json') -Encoding UTF8
Write-Output "Packaged release: $destination"
