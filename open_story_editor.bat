@echo off
setlocal
set PROJ=%~dp0
set EDITOR=%PROJ%tools\story_editor.html

if not exist "%EDITOR%" (
    echo [ERROR] Editor not found: %EDITOR%
    pause
    exit /b 1
)

rem Refresh the snapshot embedded in the page (skipped silently if python is absent).
where python >nul 2>nul
if errorlevel 1 goto open
python "%PROJ%tools\build_story_editor.py"

:open
echo Opening story text editor ...
start "" "%EDITOR%"
exit /b 0
