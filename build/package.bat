@echo off
cd /d "%~dp0\.."
powershell -ExecutionPolicy Bypass -File "build\package.ps1"
pause