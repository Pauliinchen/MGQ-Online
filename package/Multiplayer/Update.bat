@echo off
rem ----------------------------------------------------------------
rem  Update.bat
rem
rem  Changelog:
rem      Paulinchen  2026-10-23: Ran Helper.exe in place of Update.ps1
rem      Paulinchen  2026-10-08: Passed its arguments on to Update.ps1
rem      Paulinchen  2026-09-30: Created
rem
rem ----------------------------------------------------------------

rem The update replaces this file while it runs, and cmd reads a batch file one line at a time as it
rem goes, so everything after this comment stays on a single line.
"%~dp0Helper.exe" update %* & exit /b
