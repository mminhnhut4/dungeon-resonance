@echo off
setlocal DisableDelayedExpansion
set "DR_PROJECT=%~dp0."
set "DR_ENGINE=%~1"
set "DR_CHECK=0"
if /i "%~2"=="--check" set "DR_CHECK=1"
if not defined DR_ENGINE set /p "DR_ENGINE=Paste full path to your Godot 4.7.2 EXE: "
set "DR_ENGINE=%DR_ENGINE:"=%"
if not exist "%DR_ENGINE%" (
  echo Godot EXE not found. Supply the full path to the installed engine.
  goto failure
)
if not defined DR_TEAM_DATA_ROOT set "DR_TEAM_DATA_ROOT=%LOCALAPPDATA%\DungeonResonanceTeamPlay"
set "DR_LOGS=%DR_TEAM_DATA_ROOT%\logs\run_%RANDOM%_%RANDOM%"
mkdir "%DR_LOGS%" 2>nul
if not exist "%DR_LOGS%" (
  echo Cannot create the playtest log directory.
  goto failure
)
"%DR_ENGINE%" --version >"%DR_LOGS%\version.log" 2>&1
if errorlevel 1 goto logfailure
findstr /b /c:"4.7.2.stable" "%DR_LOGS%\version.log" >nul
if errorlevel 1 (
  echo This project requires Godot 4.7.2 stable.
  type "%DR_LOGS%\version.log"
  goto failure
)
set "APPDATA=%DR_TEAM_DATA_ROOT%\AppData"
set "LOCALAPPDATA=%DR_TEAM_DATA_ROOT%\LocalAppData"
mkdir "%APPDATA%" "%LOCALAPPDATA%" 2>nul
>"%DR_LOGS%\launch.txt" echo Project: %DR_PROJECT%
>>"%DR_LOGS%\launch.txt" echo Main: res://scenes/maps/prologue_hub.tscn
>>"%DR_LOGS%\launch.txt" echo Playtest data: %DR_TEAM_DATA_ROOT%
echo Importing project assets. Please wait.
"%DR_ENGINE%" --headless --editor --path "%DR_PROJECT%" --import >"%DR_LOGS%\import.log" 2>&1
if errorlevel 1 goto logfailure
findstr /i /c:"ERROR:" /c:"WARNING:" /c:"SCRIPT ERROR" "%DR_LOGS%\import.log" >nul
if not errorlevel 1 goto logfailure
echo Starting the complete game from its main scene.
echo Logs: %DR_LOGS%
if "%DR_CHECK%"=="1" (
  "%DR_ENGINE%" --headless --path "%DR_PROJECT%" --quit-after 120 "res://scenes/maps/prologue_hub.tscn" >"%DR_LOGS%\game.log" 2>&1
) else (
  "%DR_ENGINE%" --path "%DR_PROJECT%" "res://scenes/maps/prologue_hub.tscn" >"%DR_LOGS%\game.log" 2>&1
)
if errorlevel 1 goto logfailure
findstr /i /c:"ERROR:" /c:"WARNING:" /c:"SCRIPT ERROR" "%DR_LOGS%\game.log" >nul
if not errorlevel 1 goto logfailure
echo Game closed normally. Logs: %DR_LOGS%
exit /b 0
:logfailure
echo Game/import failed. Keep these logs for diagnosis: %DR_LOGS%
if exist "%DR_LOGS%\import.log" type "%DR_LOGS%\import.log"
if exist "%DR_LOGS%\game.log" type "%DR_LOGS%\game.log"
:failure
if "%DR_CHECK%"=="0" pause
exit /b 1
