@echo off
powershell -NoProfile -File "%~dp0tools\run_team_test.ps1" %*
if errorlevel 1 pause
