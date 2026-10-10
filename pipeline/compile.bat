@echo off
setlocal enabledelayedexpansion

set ENV_CONFIG=%~dp0env\%ENV%.conf
if "%ENV%"=="" set ENV_CONFIG=%~dp0env\dev.conf
if not exist "%ENV_CONFIG%" (
    echo ERROR: Config not found: %ENV_CONFIG%
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_CONFIG%") do set %%A=%%B

set JARS_DIR=%TAFJ_HOME%\data\tafj\jars

pushd %~dp0..\bp
set BP_ROOT=%CD%
popd

echo.
echo =^> T24 BASIC Compilation [ENV: %ENV%]
echo =^> Repo bp\  : %BP_ROOT%
echo =^> BNK_HOME  : %BNK_HOME%
echo =^> TAFJ      : %TAFJ_HOME%
echo.

rem Walk bp\ recursively - each subfolder mirrors BNK_HOME
rem e.g. bp\T24_BP\AA.X.b    -> BNK_HOME\T24_BP\AA.X.b
rem      bp\UD\AUTH.BP\X.b   -> BNK_HOME\UD\AUTH.BP\X.b

set COMPILED=0
set FAILED=0
set SYNCED=0

for /r "%BP_ROOT%" %%F in (*.b) do (
    rem Get path of file relative to BP_ROOT
    set "FULL=%%F"
    set "REL=!FULL:%BP_ROOT%\=!"

    rem Determine target folder on server (strip filename from REL)
    for %%D in ("%%~dpF.") do set "TARGET_DIR=%BNK_HOME%\!REL!"
    rem Remove the filename to get just the folder
    set "TARGET_DIR=%BNK_HOME%\!REL!"
    for %%X in ("!TARGET_DIR!") do set "TARGET_DIR=%%~dpX"

    rem Create target dir if missing
    if not exist "!TARGET_DIR!" mkdir "!TARGET_DIR!"

    rem Sync file to BNK_HOME location
    copy /y "%%F" "!TARGET_DIR!" >nul
    echo    Synced: !REL!
    set /a SYNCED+=1

    rem Compile from the BNK_HOME location
    set "SERVER_PATH=%BNK_HOME%\!REL!"
    call "%TAFJ_HOME%\bin\tCompile.bat" "!SERVER_PATH!"
    if errorlevel 1 (
        echo    ERROR: !REL!
        set /a FAILED+=1
    ) else (
        set /a COMPILED+=1
    )
    echo.
)

if !SYNCED!==0 (
    echo No .b files found under %BP_ROOT%
    exit /b 1
)

echo.
if !FAILED! GTR 0 (
    echo =^> Result: !COMPILED! compiled, !FAILED! FAILED
    exit /b 1
)

echo =^> Result: !COMPILED! compiled, 0 failed
echo.
echo =^> JARs produced:
for %%J in (%JARS_DIR%\*.jar) do echo    %%~nxJ

endlocal
exit /b 0
