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
set MODULE_XML=%JBOSS_HOME%\modules\com\temenos\t24\main\module.xml
set SCRIPT_DIR=%~dp0

echo.
echo =^> T24 Deploy [ENV: %ENV%]
echo =^> JBoss local : %JBOSS_MODULE_LOCAL%
echo =^> module.xml  : %MODULE_XML%
echo.

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

echo =^> Deploying JARs...
set DEPLOYED=0
for %%J in (%JARS_DIR%\*.jar) do (
    if !LINKED!==0 (
        copy /y "%%J" "%JBOSS_MODULE_LOCAL%\" >nul
    )
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update-module.ps1" -ModuleXml "%MODULE_XML%" -JarName "%%~nxJ"
    set /a DEPLOYED+=1
)

if !DEPLOYED!==0 (
    echo    No JARs found in %JARS_DIR%
    exit /b 1
)

echo.
echo =^> Checking JBoss state [port %JBOSS_MGMT_PORT%]...
powershell -NoProfile -Command "try { $t=New-Object Net.Sockets.TcpClient; $t.Connect('localhost',%JBOSS_MGMT_PORT%); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo    JBoss not running - JARs will load on next start
) else (
    echo    JBoss running - reloading...
    echo. | "%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":reload" 2>&1
    echo    Reload triggered
)

echo.
echo =^> Deploy complete - %DEPLOYED% jar(s) deployed

rem Record this commit as deployed so the next run only compiles newer changes
if not exist "%BNK_HOME%\.cicd" mkdir "%BNK_HOME%\.cicd"
git -C "%~dp0.." rev-parse HEAD > "%BNK_HOME%\.cicd\last_deployed_%ENV%.txt"
if errorlevel 1 (
    echo ERROR: could not record deployed commit
    exit /b 1
)
echo =^> Recorded deployed commit for %ENV%
endlocal
exit /b 0
