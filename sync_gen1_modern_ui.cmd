@echo off
setlocal

rem Sync the unpacked Gen1 Modern UI mod into the LOVE save directory.
set "GEN1_UI_SOURCE=%~dp0mods\gen1_modern_ui"
set "GEN1_UI_TARGET=%APPDATA%\pokemon-love2d\mods\gen1_modern_ui"
set "GEN1_UI_PROJECT=%~dp0"

if not exist "%GEN1_UI_SOURCE%\manifest.json" (
  echo ERROR: Could not find the mod source at:
  echo        "%GEN1_UI_SOURCE%"
  echo Run this script from the Gen1 Modern UI repository.
  pause
  exit /b 1
)

echo Syncing Gen1 Modern UI...
echo   From: "%GEN1_UI_SOURCE%"
echo   To:   "%GEN1_UI_TARGET%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $source = [IO.Path]::GetFullPath($env:GEN1_UI_SOURCE); $target = [IO.Path]::GetFullPath($env:GEN1_UI_TARGET); New-Item -ItemType Directory -Force -Path $target | Out-Null; Get-ChildItem -LiteralPath $source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force }"

if errorlevel 1 (
  echo.
  echo ERROR: The mod could not be synced.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%GEN1_UI_PROJECT%build_gen1_modern_ui.ps1"

if errorlevel 1 (
  echo.
  echo ERROR: The mod could not be synced.
  pause
  exit /b 1
)

echo.
echo Gen1 Modern UI synced successfully.
echo A launcher-ready zip was created in the project root.
echo Restart the game to reload the mod.
pause
exit /b 0
