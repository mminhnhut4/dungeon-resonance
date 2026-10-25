@echo off
powershell -NoProfile -File "%~dp0tools\run_team_test.ps1" -NormalProgression %*
if errorlevel 1 pause
