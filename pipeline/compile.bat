@echo off
setlocal enabledelayedexpansion

set TAFJ_HOME=C:\R25\TAFJ
set BNK_HOME=C:\R25\bnk
set T24_LOCAL=%BNK_HOME%\local
set JARS_DIR=%TAFJ_HOME%\data\tafj\jars

pushd %~dp0..\bp
set BP_DIR=%CD%
popd

echo.
echo =^> T24 BASIC Compilation
echo =^> Source : %BP_DIR%
echo =^> Jars   : %JARS_DIR%
echo.

if not exist "%T24_LOCAL%" mkdir "%T24_LOCAL%"

rem Compile each .b file - tCompile reads all config from tafj.properties
set COMPILED=0
set FAILED=0
for %%F in (%BP_DIR%\*.b) do (
    echo    Compiling: %%~nxF
    call "C:\R25\TAFJ\bin\tCompile.bat" "%%F"
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

rem Copy produced component JARs to bnk/local for deployment
echo.
echo =^> Copying component JARs to %T24_LOCAL%
set COPIED=0
for %%J in (%JARS_DIR%\*.jar) do (
    copy /y "%%J" "%T24_LOCAL%\" >nul
    echo    Copied: %%~nxJ
    set /a COPIED+=1
)

echo.
echo =^> Done: !COMPILED! compiled, !FAILED! failed, !COPIED! jar(s) staged to %T24_LOCAL%
if !FAILED! GTR 0 exit /b 1
endlocal
