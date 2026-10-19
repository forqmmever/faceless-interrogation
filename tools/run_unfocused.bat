@echo off
rem Run a Godot scene in a window that does NOT steal focus / stay on top.
rem Usage: run_unfocused.bat res://tests/Screenshot.tscn
setlocal
set GODOT=D:\WorkBuddy\godot\Godot_v4.3-stable_win64.exe
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_unfocused.ps1" -Scene "%~1"
