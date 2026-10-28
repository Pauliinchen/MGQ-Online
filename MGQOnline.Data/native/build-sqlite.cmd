@echo off
rem ----------------------------------------------------------------
rem  build-sqlite.cmd
rem
rem  Changelog:
rem      Paulinchen  2026-10-28: Created
rem
rem ----------------------------------------------------------------

rem Compiles the SQLite amalgamation into a static library with the Visual Studio C++ tools, found
rem the way NativeAOT's findvcvarsall.bat finds them. StaticSqlite.targets runs it in a publish.
rem
rem   build-sqlite.cmd <x86|x64|arm64> <sqlite3.c> <out .lib> "<compiler flags>"

setlocal
set arch=%~1
set source=%~2
set library=%~3
set flags=%~4

set vswhere=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
if not exist "%vswhere%" goto :notools
set tools=x86.x64
if /i "%arch%"=="arm64" set tools=ARM64
for /f "tokens=*" %%i in ('"%vswhere%" -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.%tools% -property installationPath') do set vs=%%i
if "%vs%"=="" goto :notools

set host=amd64
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set host=arm64
set target=%arch%
if /i "%arch%"=="x64" set target=amd64
set environment=%host%_%target%
if /i "%host%"=="%target%" set environment=%host%

call "%vs%\VC\Auxiliary\Build\vcvarsall.bat" %environment% >nul
if errorlevel 1 goto :notools

set object=%library:.lib=.obj%
cl /nologo /c /O1 /Os /MT /W0 %flags% /Fo"%object%" "%source%"
if errorlevel 1 exit /b 1
lib /nologo /out:"%library%" "%object%"
if errorlevel 1 exit /b 1
exit /b 0

:notools
echo build-sqlite.cmd: error: the Visual Studio C++ tools for %arch% were not found; install the Desktop development with C++ workload.
exit /b 1
