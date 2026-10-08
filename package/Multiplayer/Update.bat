@echo off
rem ----------------------------------------------------------------
rem  Update.bat
rem
rem  Changelog:
rem      Paulinchen  2026-10-08: Passed its arguments on to Update.ps1, which the game gives when it starts the update
rem      Paulinchen  2026-09-30: Created
rem
rem ----------------------------------------------------------------

rem The update replaces this file while it runs, and cmd reads a batch file one line at a time as it
rem goes, so everything after this comment stays on a single line.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update.ps1" %* & pause & exit /b
