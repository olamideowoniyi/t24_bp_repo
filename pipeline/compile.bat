@echo off
setlocal enabledelayedexpansion

rem Load environment config
set ENV_CONFIG=%~dp0env\%ENV%.conf
if "%ENV%"=="" set ENV_CONFIG=%~dp0env\dev.conf
if not exist "%ENV_CONFIG%" (
    echo ERROR: Config not found: %ENV_CONFIG%
    exit /b 1
)
for /f "usebackq tokens=1,2 delims==" %%A in ("%ENV_CONFIG%") do set %%A=%%B

set T24_LOCAL=%BNK_HOME%\local
set JARS_DIR=%TAFJ_HOME%\data\tafj\jars

pushd %~dp0..\bp
set BP_DIR=%CD%
popd

echo.
echo =^> T24 BASIC Compilation [ENV: %ENV%]
echo =^> Source : %BP_DIR%
echo =^> TAFJ   : %TAFJ_HOME%
echo =^> Output : %T24_LOCAL%
echo.

if not exist "%T24_LOCAL%" mkdir "%T24_LOCAL%"

set COMPILED=0
set FAILED=0
for %%F in (%BP_DIR%\*.b) do (
    echo    Compiling: %%~nxF
    call "%TAFJ_HOME%\bin\tCompile.bat" "%%F"
    if errorlevel 1 (
        echo    ERROR: %%~nxF
        set /a FAILED+=1
    ) else (
        set /a COMPILED+=1
    )
)

if !COMPILED!==0 (
    if !FAILED!==0 (
        echo No .b files found in %BP_DIR%
        exit /b 1
    ) else (
        echo All files failed to compile
        exit /b 1
    )
)

echo.
echo =^> Copying JARs to %T24_LOCAL%
set COPIED=0
for %%J in (%JARS_DIR%\*.jar) do (
    copy /y "%%J" "%T24_LOCAL%\" >nul
    echo    Copied: %%~nxJ
    set /a COPIED+=1
)

echo.
echo =^> Done: !COMPILED! compiled, !FAILED! failed, !COPIED! jar(s) ready
if !FAILED! GTR 0 exit /b 1
endlocal
