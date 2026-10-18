@echo off
setlocal
set PROJ=%~dp0
set EDITOR=%PROJ%tools\story_editor.html

if not exist "%EDITOR%" (
    echo [ERROR] Editor not found: %EDITOR%
    pause
    exit /b 1
)

where python >nul 2>nul
if errorlevel 1 goto nopython

rem 内置快照刷一遍 —— 只在「没连上服务、双击 HTML」时当只读退路用。
python "%PROJ%tools\build_story_editor.py"

rem ★ 第七十六轮：编辑器直接读写 data\story.json，靠这个本地小服务。
rem   页面固定 127.0.0.1:8765；保存 = 直接写回文件（旧版留 data\story.json.bak）。
start "story-editor-server" /min python "%PROJ%tools\story_server.py" --no-open
timeout /t 1 >nul
start "" "http://127.0.0.1:8765/"
exit /b 0

:nopython
echo [WARN] No python found - the editor opens in READ-ONLY mode (file://).
echo        Saving needs tools\story_server.py, which needs Python.
start "" "%EDITOR%"
exit /b 0
