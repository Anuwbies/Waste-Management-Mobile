@echo off
title RecyClean - Full Stack Launcher
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0start-all.ps1"
pause
