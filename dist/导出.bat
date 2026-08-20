@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================
echo   Roblox .rbxl Code Export Tool v1.0
echo   - Double-click: export ALL .rbxl in this folder
echo   - Drag a .rbxl onto this file: export only it
echo ============================================
echo.

REM ===== 1. Check for updates (controlled by author, see 更新源.txt) =====
if exist "更新源.txt" (
	for /f "usebackq eol=# tokens=*" %%U in ("更新源.txt") do (
		if not "%%U"=="" call :check_update "%%U"
	)
)

REM ===== 2. Decide export mode =====
if not "%~1"=="" (
	echo [MODE] File specified: %~1
	"%~dp0lune.exe" run export_scenes.lua -- "%~1"
) else (
	set HAS_RBXL=0
	for %%F in (*.rbxl) do set HAS_RBXL=1
	if "!HAS_RBXL!"=="0" (
		echo [HINT] No .rbxl file found in this folder.
		echo        Copy your Roblox place files ^(.rbxl^) here, then run again.
		goto :end
	)
	echo [MODE] Auto-scan all .rbxl in this folder
	"%~dp0lune.exe" run export_scenes.lua
)

REM ===== 3. Result =====
if errorlevel 1 (
	echo.
	echo [FAILED] Export error - please screenshot the message above.
) else (
	echo.
	echo [DONE] Export finished! Results are in the "export" folder.
	if exist "export" start "" "export"
)
goto :end

:check_update
REM arg = update source prefix, e.g. https://raw.githubusercontent.com/USER/REPO/main
set "SRC=%~1"
if "!SRC!"=="" exit /b
set "LOCAL_VERSION="
if exist "VERSION.txt" set /p LOCAL_VERSION=<"VERSION.txt"
curl -s -m 15 -o "_remote_version.txt" "!SRC!/VERSION.txt"
if exist "_remote_version.txt" (
	set "REMOTE_VERSION="
	set /p REMOTE_VERSION=<"_remote_version.txt"
	if not "!REMOTE_VERSION!"=="" (
		if not "!REMOTE_VERSION!"=="!LOCAL_VERSION!" (
			echo [UPDATE] New version !REMOTE_VERSION! ^(current !LOCAL_VERSION!^), downloading...
			curl -s -m 30 -o "export_scenes.lua.new" "!SRC!/export_scenes.lua"
			if exist "export_scenes.lua.new" (
				move /y "export_scenes.lua.new" "export_scenes.lua" >nul
				copy /y "_remote_version.txt" "VERSION.txt" >nul
				echo [UPDATE] Updated to !REMOTE_VERSION!
			) else (
				echo [UPDATE] Download failed, keeping current version
			)
		) else (
			echo [UPDATE] Already up to date
		)
	)
	del "_remote_version.txt" >nul 2>&1
)
exit /b

:end
echo.
pause
