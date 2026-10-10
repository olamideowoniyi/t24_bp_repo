@echo off
setlocal enabledelayedexpansion

set ENV_CONFIG=%~dp0env\%ENV%.conf
if "%ENV%"=="" set ENV_CONFIG=%~dp0env\dev.conf
if not exist "%ENV_CONFIG%" (
    echo ERROR: Config not found: %ENV_CONFIG%
    exit /b 1
)
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%ENV_CONFIG%") do set %%A=%%B

rem Switches: config value, else default; a one-off override from the
rem "Run workflow" button wins (Y/N; "config" or empty = use the config)
if "%DEPLOY_TO_JBOSS%"=="" set DEPLOY_TO_JBOSS=Y
if "%JBOSS_RELOAD%"=="" set JBOSS_RELOAD=N
if /i "%DEPLOY_OVERRIDE%"=="Y" set DEPLOY_TO_JBOSS=Y
if /i "%DEPLOY_OVERRIDE%"=="N" set DEPLOY_TO_JBOSS=N
if /i "%RELOAD_OVERRIDE%"=="Y" set JBOSS_RELOAD=Y
if /i "%RELOAD_OVERRIDE%"=="N" set JBOSS_RELOAD=N

set JARS_DIR=%TAFJ_HOME%\data\tafj\jars
set MODULE_XML=%JBOSS_HOME%\modules\com\temenos\t24\main\module.xml
set SCRIPT_DIR=%~dp0
set CICD_DIR=%BNK_HOME%\.cicd
rem Jars compiled while JBoss deploy was off - deployed by the next run with it on
set PENDING=%CICD_DIR%\pending_jboss_%ENV%.txt

set WORK=%RUNNER_TEMP%
if "%WORK%"=="" set WORK=%TEMP%
set JAR_LIST=%WORK%\t24cicd_jars.txt
set TODO=%WORK%\t24cicd_deploy_jars.txt

if not exist "%CICD_DIR%" mkdir "%CICD_DIR%"

echo.
echo =^> T24 Deploy [ENV: %ENV%]
echo =^> Deploy to JBoss : %DEPLOY_TO_JBOSS%
echo =^> Reload JBoss    : %JBOSS_RELOAD%
echo =^> JBoss local     : %JBOSS_MODULE_LOCAL%
echo =^> module.xml      : %MODULE_XML%
echo.

if not exist "%JAR_LIST%" (
    echo    WARNING: no jar list from the compile step - nothing new from this run
    type nul > "%JAR_LIST%"
)

rem Jars from this run plus any still pending from earlier compile-only runs
type nul > "%TODO%"
powershell -NoProfile -Command "$j = @('%JAR_LIST%','%PENDING%') | Where-Object { Test-Path $_ } | ForEach-Object { Get-Content $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique; if ($j) { Set-Content '%TODO%' $j }; exit 0"
if errorlevel 1 (
    echo ERROR: could not build the list of jars to deploy
    exit /b 1
)
set COUNT=0
for /f "usebackq delims=" %%J in ("%TODO%") do set /a COUNT+=1

if /i "%DEPLOY_TO_JBOSS%"=="N" goto :compile_only
if !COUNT!==0 (
    echo    No new jars - nothing to deploy to JBoss
    goto :record
)

if not exist "%MODULE_XML%" (
    echo ERROR: module.xml not found: %MODULE_XML%
    exit /b 1
)

rem Ensure JBoss local folder exists
if not exist "%JBOSS_MODULE_LOCAL%" (
    echo    Creating %JBOSS_MODULE_LOCAL%
    mkdir "%JBOSS_MODULE_LOCAL%"
)

rem Check if JBOSS_MODULE_LOCAL is a symlink/junction - if so, skip the copy
set LINKED=0
powershell -NoProfile -Command "if ((Get-Item '%JBOSS_MODULE_LOCAL%').LinkType) { exit 1 } else { exit 0 }" >nul 2>&1
if errorlevel 1 set LINKED=1
if !LINKED!==1 echo    Note: JBoss local is a linked folder - skipping copy

echo =^> Deploying !COUNT! jar^(s^)...
set FAILED=0
for /f "usebackq delims=" %%J in ("%TODO%") do (
    if not exist "%JARS_DIR%\%%J" (
        echo    ERROR: jar not found: %JARS_DIR%\%%J
        set /a FAILED+=1
    ) else (
        if !LINKED!==0 (
            copy /y "%JARS_DIR%\%%J" "%JBOSS_MODULE_LOCAL%\" >nul
            if errorlevel 1 (
                echo    ERROR: copy failed: %%J
                set /a FAILED+=1
            ) else (
                echo    Copied: %%J
            )
        )
        rem Adds the module.xml entry only if it is not there yet
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update-module.ps1" -ModuleXml "%MODULE_XML%" -JarName "%%J"
        if errorlevel 1 (
            echo    ERROR: module.xml update failed: %%J
            set /a FAILED+=1
        )
    )
)
if !FAILED! GTR 0 (
    echo.
    echo =^> Deploy FAILED for !FAILED! jar^(s^) - pending list kept, commit not recorded
    exit /b 1
)

rem Everything pending is now in JBoss
if exist "%PENDING%" del "%PENDING%"

echo.
if /i not "%JBOSS_RELOAD%"=="Y" (
    echo    JBoss reload is OFF - new jars load at the next JBoss restart
    goto :record
)
echo =^> Checking JBoss state [port %JBOSS_MGMT_PORT%]...
powershell -NoProfile -Command "try { $t=New-Object Net.Sockets.TcpClient; $t.Connect('localhost',%JBOSS_MGMT_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo    JBoss not running - jars will load on next start
) else (
    echo    JBoss running - reloading...
    echo. | "%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":reload" 2>&1
    echo    Reload triggered
)
goto :record


:compile_only
rem Keep the jars pending so the next run with JBoss deploy on picks them up
copy /y "%TODO%" "%PENDING%" >nul
echo =^> JBoss deploy is OFF - compiled only: command-line TAFJ (tRun, DBTools) uses the new code, JBoss untouched
echo    !COUNT! jar^(s^) waiting for JBoss:
for /f "usebackq delims=" %%J in ("%PENDING%") do echo       %%J


:record
rem Record this commit as deployed so the next run only compiles newer changes
git -C "%~dp0.." rev-parse HEAD > "%CICD_DIR%\last_deployed_%ENV%.txt"
if errorlevel 1 (
    echo ERROR: could not record deployed commit
    exit /b 1
)
echo.
echo =^> Recorded deployed commit for %ENV%
endlocal
exit /b 0
