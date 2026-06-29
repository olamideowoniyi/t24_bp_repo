@echo off
setlocal

set JBOSS_HOME=C:\R25\jboss-eap-8.1
set BNK_HOME=C:\R25\bnk
set T24_LOCAL=%BNK_HOME%\local
set MODULE_XML=%JBOSS_HOME%\modules\com\temenos\t24\main\module.xml

echo.
echo =^> Deploying JARs from %T24_LOCAL%

if not exist "%T24_LOCAL%" (
    echo ERROR: %T24_LOCAL% does not exist
    exit /b 1
)

rem Register any new JARs in module.xml
set REGISTERED=0
for %%J in ("%T24_LOCAL%\*.jar") do (
    findstr /c:"%%~nxJ" "%MODULE_XML%" >nul 2>&1
    if errorlevel 1 (
        echo    Registering %%~nxJ in module.xml...
        powershell -Command "(Get-Content '%MODULE_XML%') -replace '</resources>', '  <resource-root path=""./local/%%~nxJ"" />^
  </resources>' | Set-Content '%MODULE_XML%'"
        set /a REGISTERED+=1
    ) else (
        echo    Already registered: %%~nxJ
    )
)

echo    %REGISTERED% new entry(s) added to module.xml

rem Reload JBoss if running
echo.
echo =^> Checking JBoss state...
"%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":read-attribute(name=server-state)" >nul 2>&1
if errorlevel 1 (
    echo    JBoss not running - JARs will be picked up on next start
) else (
    echo    JBoss running - reloading...
    "%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":reload"
    echo    Reload triggered
)

echo.
echo =^> Deploy complete
endlocal
