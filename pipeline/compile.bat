@echo off
setlocal enabledelayedexpansion

set ENV_CONFIG=%~dp0env\%ENV%.conf
if "%ENV%"=="" set ENV_CONFIG=%~dp0env\dev.conf
if not exist "%ENV_CONFIG%" (
    echo ERROR: Config not found: %ENV_CONFIG%
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_CONFIG%") do set %%A=%%B

set T24_BP=%BNK_HOME%\T24_BP
set JARS_DIR=%TAFJ_HOME%\data\tafj\jars

pushd %~dp0..\bp\src
set SRC_DIR=%CD%
popd

echo.
echo =^> T24 BASIC Compilation [ENV: %ENV%]
echo =^> Source   : %SRC_DIR%
echo =^> T24_BP   : %T24_BP%
echo =^> TAFJ     : %TAFJ_HOME%
echo.

if not exist "%T24_BP%" (
    echo ERROR: T24_BP not found: %T24_BP%
    exit /b 1
)

rem Sync changed .b files into T24_BP so tCompile can resolve INSERT references
echo =^> Syncing source files to T24_BP...
set SYNCED=0
for %%F in (%SRC_DIR%\*.b) do (
    copy /y "%%F" "%T24_BP%\" >nul
    echo    Synced: %%~nxF
    set /a SYNCED+=1
)
if !SYNCED!==0 (
    echo    No .b files found in %SRC_DIR%
    exit /b 1
)

echo.
echo =^> Compiling...
set COMPILED=0
set FAILED=0
for %%F in (%SRC_DIR%\*.b) do (
    echo    %%~nxF
    call "%TAFJ_HOME%\bin\tCompile.bat" "%T24_BP%\%%~nxF"
    if errorlevel 1 (
        echo    ERROR compiling %%~nxF
        set /a FAILED+=1
    ) else (
        set /a COMPILED+=1
    )
)

echo.
if !FAILED! GTR 0 (
    echo =^> Compile result: !COMPILED! ok, !FAILED! FAILED - aborting
    exit /b 1
)

echo =^> Compile result: !COMPILED! compiled, 0 failed
echo.
echo =^> JARs produced in %JARS_DIR%:
for %%J in (%JARS_DIR%\*.jar) do echo    %%~nxJ

endlocal
exit /b 0
