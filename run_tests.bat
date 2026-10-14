@echo off
setlocal
set GODOT=D:\WorkBuddy\godot\Godot_v4.3-stable_win64_console.exe
set PROJ=D:\WorkBuddy\2026-10-11-09-19-59

echo =========================================
echo  [1/4] Wardrobe + data layer unit tests
echo =========================================
"%GODOT%" --headless --fixed-fps 60 --path "%PROJ%" res://tests/WardrobeTest.tscn --quit-after 2400

echo.
echo =========================================
echo  [2/4] End-to-end tests
echo =========================================
"%GODOT%" --headless --fixed-fps 60 --path "%PROJ%" res://tests/TestRunner.tscn --quit-after 2400

echo.
echo =========================================
echo  [3/4] Story editor smoke test (needs node)
echo =========================================
where node >nul 2>nul
if errorlevel 1 (
    echo   [SKIP] node not found on PATH
) else (
    node "%PROJ%\tools\editor_smoke.js"
)

echo.
echo =========================================
echo  [4/4] Phone editor smoke test (needs node)
echo =========================================
where node >nul 2>nul
if errorlevel 1 (
    echo   [SKIP] node not found on PATH
) else (
    python "%PROJ%\tools\build_phone_editor.py"
    node "%PROJ%\tools\phone_editor_smoke.js"
)

echo.
echo All test suites finished.
pause
