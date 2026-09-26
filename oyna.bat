@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "GODOT="
set "BESTVER="

rem where godot finds godot.cmd. The exe may sit beside that file or in a WinGet package folder.
for /f "delims=" %%I in ('where godot.cmd 2^>nul') do (
  for %%F in ("%%~dpIGodot_v*_win64.exe") do (
    if exist "%%~fF" call :consider "%%~fF"
  )
)

for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
  for %%F in ("%%D\Godot_v*_win64.exe") do (
    if exist "%%~fF" call :consider "%%~fF"
  )
)

for /d %%D in ("%ProgramFiles%\WinGet\Packages\GodotEngine.GodotEngine_*") do (
  for %%F in ("%%D\Godot_v*_win64.exe") do (
    if exist "%%~fF" call :consider "%%~fF"
  )
)

if not defined GODOT (
  echo Godot bulunamadi.
  echo Once hazirla.bat dosyasini calistir.
  pause
  exit /b 1
)

start "" "%GODOT%" --path "%CD%"
exit /b 0

:consider
set "CAND=%~1"
set "VER=%~n1"
set "VER=%VER:*Godot_v=%"
for /f "tokens=1 delims=-" %%V in ("%VER%") do set "VER=%%V"
echo %VER%| findstr /r "^[0-9][0-9]*\.[0-9][0-9]*" >nul || goto :eof
set "MAJ="
set "MIN="
set "PAT="
for /f "tokens=1-3 delims=." %%A in ("%VER%") do (
  set "MAJ=%%A"
  set "MIN=%%B"
  set "PAT=%%C"
)
if not defined MIN set "MIN=0"
if not defined PAT set "PAT=0"
set /a SCORE=MAJ*1000000 + MIN*1000 + PAT >nul
if not defined BESTVER (
  set "BESTVER=%SCORE%"
  set "GODOT=%CAND%"
  goto :eof
)
if %SCORE% GTR %BESTVER% (
  set "BESTVER=%SCORE%"
  set "GODOT=%CAND%"
)
goto :eof
