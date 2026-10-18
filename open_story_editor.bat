@echo off
rem ============================================================
rem  Open the story editor with a local write-back service.
rem
rem  Why a service: a web page cannot write to data\story.json by
rem  itself, so tools\story_server.py serves the page on
rem  127.0.0.1:8765 and writes the file when you press Save.
rem
rem  NOTE: everything in this file is ASCII on purpose. A .bat is
rem  read with the system OEM codepage (936 on this machine); saving
rem  the file as UTF-8 turns every Chinese line into mojibake, and
rem  re-saving it through an editor that assumes UTF-8 turns those
rem  bytes into literal "?" characters. Keeping it ASCII-only means
rem  no editor can ever corrupt it.
rem ============================================================
setlocal EnableExtensions
set "PROJ=%~dp0"
set "EDITOR=%PROJ%tools\story_editor.html"
set "SERVER=%PROJ%tools\story_server.py"
set "PORT=8765"
if not "%STORY_EDITOR_PORT%"=="" set "PORT=%STORY_EDITOR_PORT%"
rem How many extra ports to try before giving up (8765 -> 8766 -> 8767 ...)
set "SPAN=3"
set "LOGDIR=%PROJ%.workbuddy-ai\tmp"
set "LOG=%LOGDIR%\story_server.log"
set "SRVURL="
set /a P2=%PORT%+1
set /a P3=%PORT%+2

if not exist "%EDITOR%" (
    echo [ERROR] Editor not found: %EDITOR%
    ping -n 11 127.0.0.1 >nul 2>nul
    exit /b 1
)
if not exist "%SERVER%" (
    echo [ERROR] Local service not found: %SERVER%
    ping -n 11 127.0.0.1 >nul 2>nul
    exit /b 1
)
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>nul

rem ------------------------------------------------------------
rem  1. Find a python that can actually run a script.
rem     Do not trust "where python": the Microsoft Store one is a
rem     stub that opens the Store, and "found" does not mean "runs".
rem     Every candidate is really executed once before it is used.
rem ------------------------------------------------------------
set "PY="
call :probe_cmd "py -3"
call :probe_cmd "python"
if not defined PY call :probe_exe "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if not defined PY call :probe_exe "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PY call :probe_exe "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PY call :probe_exe "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PY call :probe_exe "%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
if not defined PY call :probe_exe "%ProgramFiles%\Python313\python.exe"
if not defined PY call :probe_exe "%ProgramFiles%\Python312\python.exe"
if not defined PY call :probe_exe "%ProgramFiles%\Python311\python.exe"
if not defined PY goto nopython

rem Refresh the embedded snapshot. Only the read-only fallback uses it
rem (a plain file:// open), but keeping it fresh costs under a second.
"%PY%" "%PROJ%tools\build_story_editor.py" >nul 2>nul

rem ------------------------------------------------------------
rem  Use pythonw.exe when it is available: that is the same interpreter
rem  without a console, so the service runs in the background and NO
rem  window is left on screen. This is the fix for "a window pops up
rem  and I have to close it by hand".
rem  Stop the service from the editor header ("Stop service") instead.
rem ------------------------------------------------------------
set "PYW="
for %%D in ("%PY%") do if exist "%%~dpDpythonw.exe" set "PYW=%%~dpDpythonw.exe"
if not defined PYW set "PYW=%PY%"

rem ------------------------------------------------------------
rem  2. Already running? Reuse it, do not start a second one.
rem     Only three ports are checked: that is the window the service
rem     itself may have shifted into when 8765 was taken.
rem ------------------------------------------------------------
call :alive %PORT%
if not errorlevel 1 goto ready
call :alive %P2%
if not errorlevel 1 goto ready
call :alive %P3%
if not errorlevel 1 goto ready

rem ------------------------------------------------------------
rem  3. Start the service, then WAIT until it reports its URL.
rem     The old version opened the browser after "timeout /t 1";
rem     a cold start plus reading 200 KB of JSON often takes longer,
rem     so the browser arrived first and showed
rem     "127.0.0.1 refused to connect".
rem ------------------------------------------------------------
if exist "%LOG%" del "%LOG%" >nul 2>nul
if "%PYW%"=="%PY%" (
    rem No pythonw next to this interpreter - fall back to a minimized console.
    start "story-editor-server" /min "%PY%" "%SERVER%" --no-open --log "%LOG%" --port %PORT% --auto-port %SPAN%
) else (
    start "" /b "%PYW%" "%SERVER%" --no-open --log "%LOG%" --port %PORT% --auto-port %SPAN%
)

set /a TRY=0
:wait
call :read_url
if defined SRVURL goto ready
set /a TRY+=1
if %TRY% GEQ 20 goto failed
rem Do not use "timeout /t 1" here: when stdin is not a console it
rem errors out with "default option is not allowed more than 1 time"
rem and does NOT wait, so the loop would spin at full speed.
ping -n 2 127.0.0.1 >nul 2>nul
goto wait

:ready
echo Service ready: %SRVURL%
echo (no window to keep - it runs in the background; stop it from the editor header)
if not "%STORY_EDITOR_NO_OPEN%"=="1" start "" "%SRVURL%"
exit /b 0

:failed
echo.
echo [ERROR] The local service did not come up.
echo.
if exist "%LOG%" (
    echo ---- service log ----
    type "%LOG%"
    echo --------------------
) else (
    echo No log file at all - python most likely never started.
)
echo.
echo Usual causes:
echo   1. Ports %PORT%-%P3% are taken - close whatever is using them,
echo      or point the launcher at a free one:
echo         set STORY_EDITOR_PORT=9100
echo   2. Antivirus / firewall blocks python from listening on localhost
echo   3. Python install is broken - run it by hand to see the error:
echo         "%PY%" "%SERVER%" --no-open
echo.
echo Opening the editor in READ-ONLY mode (you can look, but not save).
if not "%STORY_EDITOR_NO_OPEN%"=="1" start "" "%EDITOR%"
echo.
echo This window closes itself in 20 seconds (log: %LOG%).
ping -n 21 127.0.0.1 >nul 2>nul
exit /b 1

:nopython
echo.
echo [WARN] No usable python found - opening the editor in READ-ONLY mode (file://).
echo        To save into data\story.json, install Python 3 and tick
echo        "Add Python to PATH" during setup.
echo.
if not "%STORY_EDITOR_NO_OPEN%"=="1" start "" "%EDITOR%"
echo.
echo This window closes itself in 10 seconds.
ping -n 11 127.0.0.1 >nul 2>nul
exit /b 0

rem ---------------- helpers ----------------

rem Ask a "command plus args" candidate (py -3 / python) for its real exe path.
:probe_cmd
if defined PY exit /b 0
for /f "usebackq delims=" %%P in (`%~1 -c "import sys;print(sys.executable)" 2^>nul`) do call :probe_exe "%%P"
exit /b 0

rem Accept an exe only if it exists, is not the Store stub, and runs -c.
:probe_exe
if defined PY exit /b 0
if not exist "%~1" exit /b 0
echo "%~1" | find /i "\WindowsApps\" >nul
if not errorlevel 1 exit /b 0
"%~1" -c "import sys" >nul 2>nul
if errorlevel 1 exit /b 0
set "PY=%~1"
exit /b 0

rem Pick up the URL the service printed. On success SRVURL is set and the
rem caller jumps to :ready, so the caller never has to guess the port.
:read_url
set "SRVURL="
if not exist "%LOG%" exit /b 0
for /f "usebackq tokens=1,* delims==" %%A in (`findstr /b /c:"URL=" "%LOG%" 2^>nul`) do set "SRVURL=%%B"
exit /b 0

rem Is OUR service answering on the given port?
rem   Two traps handled here:
rem   1. Do not settle for "some HTTP response". With a proxy or gateway in
rem      the way, a dead service still returns a 502 page. Require the
rem      story.json schema name in the body, so only our server counts.
rem   2. Bypass the proxy explicitly. Many VPN / dev tools export
rem      http_proxy, and curl honours it even for 127.0.0.1 - the request
rem      would then go out through the proxy and never reach our server.
:alive
set "URL=http://127.0.0.1:%~1/"
where curl >nul 2>nul
if errorlevel 1 goto alive_ps
curl -s --noproxy "*" --max-time 1 "%URL%api/story" | find /i "faceless-story" >nul
if errorlevel 1 exit /b 1
set "SRVURL=%URL%"
exit /b 0
:alive_ps
powershell -NoProfile -Command "$wc=New-Object Net.WebClient; $wc.Proxy=$null; try{$s=$wc.DownloadString('%URL%api/story'); if($s -match 'faceless-story'){exit 0}}catch{}; exit 1" >nul 2>nul
if errorlevel 1 exit /b 1
set "SRVURL=%URL%"
exit /b 0
