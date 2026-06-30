@echo off
setlocal

set JBOSS_HOME=C:\R25\jboss-eap-8.1
set BNK_HOME=C:\R25\bnk
set T24_LOCAL=%BNK_HOME%\local
set MODULE_XML=%JBOSS_HOME%\modules\com\temenos\t24\main\module.xml
set SCRIPT_DIR=%~dp0

echo.
echo =^> Deploying JARs from %T24_LOCAL%

if not exist "%T24_LOCAL%" (
    echo ERROR: %T24_LOCAL% does not exist
    exit /b 1
)

rem Register any new JARs in module.xml via PowerShell script
for %%J in ("%T24_LOCAL%\*.jar") do (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update-module.ps1" -ModuleXml "%MODULE_XML%" -JarName "%%~nxJ"
)

rem Check JBoss management port with proper connection test
echo.
echo =^> Checking JBoss state...
powershell -Command "try { $t=New-Object Net.Sockets.TcpClient; $t.Connect('localhost',9990); $t.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo    JBoss not running - JARs will be picked up on next start
) else (
    echo    JBoss running - reloading...
    echo. | "%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":reload" 2>&1
    echo    Reload triggered
)

echo.
echo =^> Deploy complete
endlocal
