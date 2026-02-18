@echo off
:: install.bat — Install LMS Plugin Suite into REAPER Effects directory (Windows)
::
:: Usage: Double-click install.bat OR run from Command Prompt
:: Copies all plugins, the shared DSP core, kits, and scripts into
:: %APPDATA%\REAPER\Effects\

setlocal EnableDelayedExpansion

set SCRIPT_DIR=%~dp0
set EFFECTS_DIR=%APPDATA%\REAPER\Effects
set DEST=%EFFECTS_DIR%\DRUMBANGER
set SCRIPTS_DEST=%APPDATA%\REAPER\Scripts\LMS

echo Installing LMS Plugin Suite...
echo   From: %SCRIPT_DIR%
echo   To:   %EFFECTS_DIR%
echo.

:: Create directories
if not exist "%DEST%" mkdir "%DEST%"
if not exist "%DEST%\kits" mkdir "%DEST%\kits"
if not exist "%DEST%\pool" mkdir "%DEST%\pool"
if not exist "%SCRIPTS_DEST%" mkdir "%SCRIPTS_DEST%"

:: Copy shared DSP kernel (REQUIRED — all plugins import this)
copy /Y "%SCRIPT_DIR%lms_core.jsfx-inc" "%EFFECTS_DIR%\lms_core.jsfx-inc" >nul
echo   Copied lms_core.jsfx-inc (shared DSP kernel)

:: Copy DRUMBANGER plugin files
for %%f in (lms_drumbanger.jsfx DrumbangerDroneFX.jsfx DrumbangerDroneMIDI2.jsfx NOTICE.TXT) do (
    if exist "%SCRIPT_DIR%%%f" (
        copy /Y "%SCRIPT_DIR%%%f" "%DEST%\%%f" >nul
        echo   Copied %%f
    )
)

:: Copy all other LMS plugins to Effects root
for %%f in ("%SCRIPT_DIR%lms_*.jsfx" "%SCRIPT_DIR%matchering_*.jsfx") do (
    if not "%%~nxf"=="lms_drumbanger.jsfx" (
        copy /Y "%%f" "%EFFECTS_DIR%\%%~nxf" >nul
        echo   Copied %%~nxf
    )
)

:: Copy kits
if exist "%SCRIPT_DIR%kits\" (
    xcopy /E /Y /Q "%SCRIPT_DIR%kits\*" "%DEST%\kits\" >nul
    echo   Copied kits/
)

:: Copy pool
if exist "%SCRIPT_DIR%pool\" (
    xcopy /E /Y /Q "%SCRIPT_DIR%pool\*" "%DEST%\pool\" >nul
    echo   Copied pool/
)

:: Copy service scripts to DRUMBANGER/scripts/
if not exist "%DEST%\scripts" mkdir "%DEST%\scripts"
for %%f in ("%SCRIPT_DIR%scripts\*") do (
    copy /Y "%%f" "%DEST%\scripts\%%~nxf" >nul
    echo   Copied scripts\%%~nxf
)

:: Copy LMS ReaScripts to REAPER Scripts/LMS/
for %%f in ("%SCRIPT_DIR%scripts\lms_*.lua") do (
    copy /Y "%%f" "%SCRIPTS_DEST%\%%~nxf" >nul
    echo   Copied %%~nxf to Scripts\LMS\
)

echo.
echo Done!
echo.
echo In REAPER:
echo   1. Options - Preferences - Plug-ins - JS - Re-scan
echo   2. Add any LMS plugin via the FX browser
echo.
echo For DRUMBANGER sample browser:
echo   Actions - Run ReaScript - pick %DEST%\scripts\drumbanger_service.lua
echo   Check "Run in background"
echo.
echo For session save/load/steal:
echo   Actions - Show Action List - search LMS
echo.
pause
