@echo off
setlocal
set GODOT=D:\WorkBuddy\godot\Godot_v4.3-stable_win64.exe
set PROJ=D:\WorkBuddy\2026-10-11-09-19-59

if not exist "%GODOT%" (
    echo [ERROR] Godot not found: %GODOT%
    pause
    exit /b 1
)

echo Launching Faceless Interrogation ...
start "" "%GODOT%" --path "%PROJ%"
exit /b 0
