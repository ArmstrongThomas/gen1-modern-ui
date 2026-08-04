[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

$sourcePath = [IO.Path]::GetFullPath(
  (Join-Path $PSScriptRoot "mods\gen1_modern_ui"))
$manifestPath = Join-Path $sourcePath "manifest.json"
if (-not [IO.File]::Exists($manifestPath)) {
  throw "Could not find the mod manifest at $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.id -ne "gen1_modern_ui") {
  throw "Unexpected manifest id: $($manifest.id)"
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.version)) {
  throw "The manifest has no version"
}

$archiveName = "$($manifest.id)-$($manifest.version).zip"
$archivePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $archiveName))
$projectPrefix = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd(
  [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
  [IO.Path]::DirectorySeparatorChar
if (-not $archivePath.StartsWith($projectPrefix,
    [StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to create an archive outside the project: $archivePath"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Keep launcher metadata first and use explicit POSIX entry names. This avoids
# mixed Windows separators and developer-only files that some mobile archive
# readers expose inconsistently.
$ordered = New-Object System.Collections.Generic.List[string]
$seen = @{}
foreach ($relative in @("manifest.json", "main.lua", "README.md")) {
  $path = Join-Path $sourcePath $relative
  if ([IO.File]::Exists($path)) {
    $ordered.Add($relative)
    $seen[$relative] = $true
  }
}
foreach ($file in (Get-ChildItem -LiteralPath $sourcePath -File -Recurse |
    Sort-Object FullName)) {
  $sourcePrefix = $sourcePath.TrimEnd([char[]]"\/")
  $relative = $file.FullName.Substring($sourcePrefix.Length + 1)
  if ($relative -eq ".luarc.json" -or $file.Name -eq ".gitkeep" -or
      $file.Extension -eq ".aseprite") { continue }
  if (-not $seen.ContainsKey($relative)) {
    $ordered.Add($relative)
    $seen[$relative] = $true
  }
}

if (($ordered.Count -lt 2) -or ($ordered[0] -ne "manifest.json") -or
    (-not $seen.ContainsKey("main.lua"))) {
  throw "The package must begin with manifest.json and contain main.lua"
}

if ([IO.File]::Exists($archivePath)) {
  [IO.File]::Delete($archivePath)
}

$stream = $null
$archive = $null
try {
  $stream = [IO.File]::Open($archivePath, [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write, [IO.FileShare]::None)
  $archive = [IO.Compression.ZipArchive]::new(
    $stream, [IO.Compression.ZipArchiveMode]::Create, $false)
  foreach ($relative in $ordered) {
    $entryName = $relative.Replace("\", "/")
    $entry = $archive.CreateEntry($entryName,
      [IO.Compression.CompressionLevel]::Optimal)
    $input = $null
    $output = $null
    try {
      $input = [IO.File]::OpenRead((Join-Path $sourcePath $relative))
      $output = $entry.Open()
      $input.CopyTo($output)
    }
    finally {
      if ($null -ne $output) { $output.Dispose() }
      if ($null -ne $input) { $input.Dispose() }
    }
  }
}
finally {
  if ($null -ne $archive) { $archive.Dispose() }
  if ($null -ne $stream) { $stream.Dispose() }
}

$check = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
  $names = @($check.Entries | ForEach-Object { $_.FullName })
  if ($names.Count -lt 2 -or $names[0] -ne "manifest.json") {
    throw "Portable archive verification failed: manifest.json is not first"
  }
  if ($names -notcontains "main.lua" -or $names -contains ".luarc.json") {
    throw "Portable archive verification failed: invalid root contents"
  }
  foreach ($name in $names) {
    if ($name.Contains("\")) {
      throw "Portable archive verification failed: Windows entry $name"
    }
  }
}
finally {
  $check.Dispose()
}

Write-Host "Created portable archive: $archivePath"
Write-Host "Archive root: $($ordered -join ', ')"
