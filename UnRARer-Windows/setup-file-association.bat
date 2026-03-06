@echo off
REM ============================================================
REM UnRARer - File Association Setup Script for Windows
REM Run this script as Administrator to associate .rar files
REM with UnRARer.
REM ============================================================

set APP_PATH=%~dp0UnRARer.exe

echo Setting up .rar file association for UnRARer...
echo Application path: %APP_PATH%

REM Register the file type
reg add "HKCU\Software\Classes\.rar" /ve /d "UnRARer.rar" /f
reg add "HKCU\Software\Classes\UnRARer.rar" /ve /d "RAR Archive" /f
reg add "HKCU\Software\Classes\UnRARer.rar\DefaultIcon" /ve /d "%APP_PATH%,0" /f
reg add "HKCU\Software\Classes\UnRARer.rar\shell\open\command" /ve /d "\"%APP_PATH%\" \"%%1\"" /f

echo.
echo File association has been set up successfully.
echo Double-clicking .rar files will now open them with UnRARer.
echo.
pause
