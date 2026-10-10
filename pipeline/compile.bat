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

pushd %~dp0..
set REPO_ROOT=%CD%
popd

rem Last commit successfully deployed to this environment (written by deploy.bat)
set MARKER=%BNK_HOME%\.cicd\last_deployed_%ENV%.txt

set WORK=%RUNNER_TEMP%
if "%WORK%"=="" set WORK=%TEMP%
set CHANGES=%WORK%\t24cicd_changes.txt
set DELETED=%WORK%\t24cicd_deleted.txt
set COMP_LIST=%WORK%\t24cicd_components.txt
set B_LIST=%WORK%\t24cicd_routines.txt
for %%T in ("%CHANGES%" "%DELETED%" "%COMP_LIST%" "%B_LIST%") do if exist %%T del %%T

echo.
echo =^> T24 BASIC Compilation [ENV: %ENV%]
echo =^> Repo      : %REPO_ROOT%
echo =^> BNK_HOME  : %BNK_HOME%
echo =^> TAFJ      : %TAFJ_HOME%
if "%DRY_RUN%"=="1" echo =^> DRY RUN   : nothing will be copied or compiled
echo.

rem ---------------------------------------------------------------------------
rem Work out what changed since the last successful deploy to this environment.
rem Falls back to the previous commit when there is no record yet.
rem ---------------------------------------------------------------------------
set BASE=
if exist "%MARKER%" set /p BASE=<"%MARKER%"
if not "%BASE%"=="" git -C "%REPO_ROOT%" cat-file -e %BASE% >nul 2>&1
if not "%BASE%"=="" if errorlevel 1 (
    echo    WARNING: last deployed commit %BASE% not found in history - using previous commit
    set BASE=
)
if "%BASE%"=="" (
    git -C "%REPO_ROOT%" rev-parse --verify --quiet HEAD~1 >nul 2>&1
    if errorlevel 1 (
        rem First commit in the repo: compare against the empty tree
        set BASE=4b825dc642cb6eb9a060e54bf8d69288fbee4904
    ) else (
        set BASE=HEAD~1
    )
)
echo =^> Changes since: %BASE%

git -C "%REPO_ROOT%" -c core.quotepath=off diff --name-only --diff-filter=ACMR %BASE% HEAD -- bp > "%CHANGES%"
if errorlevel 1 (
    echo ERROR: git diff failed - is the checkout complete? ^(fetch-depth: 0^)
    exit /b 1
)
git -C "%REPO_ROOT%" -c core.quotepath=off diff --name-only --diff-filter=D %BASE% HEAD -- bp > "%DELETED%"

rem ---------------------------------------------------------------------------
rem Sync every changed file under bp\ to the same place under BNK_HOME
rem (routines, .component files, inserts) and sort what needs compiling.
rem   bp\UD\AUTH.BP\X.b  ->  BNK_HOME\UD\AUTH.BP\X.b
rem ---------------------------------------------------------------------------
set SYNCED=0
set FAILED=0
set NCOMP=0
set NROUT=0

for /f "usebackq delims=" %%F in ("%CHANGES%") do (
    set "REL=%%F"
    set "REL=!REL:/=\!"
    set "REL=!REL:~3!"
    set "DEST=%BNK_HOME%\!REL!"
    for %%X in ("!DEST!") do (
        set "DEST_DIR=%%~dpX"
        set "EXT=%%~xX"
    )
    if "%DRY_RUN%"=="1" (
        echo    [dry-run] sync: !REL!
    ) else (
        if not exist "!DEST_DIR!" mkdir "!DEST_DIR!"
        copy /y "%REPO_ROOT%\bp\!REL!" "!DEST!" >nul
        if errorlevel 1 (
            echo    ERROR: copy failed: !REL!
            set /a FAILED+=1
        ) else (
            echo    Synced: !REL!
        )
    )
    set /a SYNCED+=1
    if /i "!EXT!"==".component" (
        echo "!DEST!">>"%COMP_LIST%"
        set /a NCOMP+=1
    )
    if /i "!EXT!"==".b" (
        echo "!DEST!">>"%B_LIST%"
        set /a NROUT+=1
    )
)

for /f "usebackq delims=" %%D in ("%DELETED%") do echo    NOTE: deleted in repo, left on server: %%D

if !SYNCED!==0 (
    echo    No changed files under bp\ - nothing to compile
    endlocal
    exit /b 0
)
echo.
echo =^> Changed: !SYNCED! file^(s^), !NCOMP! component^(s^), !NROUT! routine^(s^)

if !FAILED! GTR 0 (
    echo =^> Result: !FAILED! file^(s^) could not be copied
    exit /b 1
)

rem New routines come with their .component - compile components first so the
rem component jar exists, then the routines (TAFJ updates the jar for each class).
call :compile_list "%COMP_LIST%" "component"
call :compile_list "%B_LIST%" "routine"

echo.
if !FAILED! GTR 0 (
    echo =^> Result: compilation FAILED - see errors above
    exit /b 1
)

echo =^> Result: !NCOMP! component^(s^), !NROUT! routine^(s^) compiled, 0 failed
echo.
echo =^> JARs in %JARS_DIR%:
for %%J in ("%JARS_DIR%\*.jar") do echo    %%~nxJ

endlocal
exit /b 0


rem ---------------------------------------------------------------------------
rem Compile the files listed in %1, 20 per tCompile call (one TAFJ start-up
rem per batch instead of per file).
rem ---------------------------------------------------------------------------
:compile_list
if not exist "%~1" exit /b 0
set ARGS=
set N=0
for /f "usebackq delims=" %%L in ("%~1") do (
    set "ARGS=!ARGS! %%L"
    set /a N+=1
    if !N! GEQ 20 (
        call :run_tcompile "%~2"
        set ARGS=
        set N=0
    )
)
if defined ARGS call :run_tcompile "%~2"
exit /b 0

:run_tcompile
echo.
echo =^> Compiling %~1 batch:!ARGS!
if "%DRY_RUN%"=="1" exit /b 0
call "%TAFJ_HOME%\bin\tCompile.bat" !ARGS!
if errorlevel 1 (
    echo    ERROR: compilation errors in this %~1 batch
    set /a FAILED+=1
)
exit /b 0
