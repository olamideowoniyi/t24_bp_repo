@echo off
setlocal

:: ── Environment ───────────────────────────────────────────────
set JBOSS_HOME=C:\R25\jboss-eap-8.1
set BNK_HOME=C:\R25\bnk
set T24_LOCAL=%BNK_HOME%\local
set MODULE_XML=%JBOSS_HOME%\modules\com\temenos\t24\main\module.xml
set JAR_NAME=local-bp.jar

echo.
echo =^> Deploying %JAR_NAME%

:: 1. Verify JAR was produced
if not exist "%T24_LOCAL%\%JAR_NAME%" (
    echo ERROR: %T24_LOCAL%\%JAR_NAME% not found. Compile step may have failed.
    exit /b 1
)
echo    JAR found: %T24_LOCAL%\%JAR_NAME%

:: 2. Add to module.xml if not already there
findstr /c:"%JAR_NAME%" "%MODULE_XML%" >nul 2>&1
if errorlevel 1 (
    echo    Adding %JAR_NAME% to module.xml...
    powershell -Command ^
        "(Get-Content '%MODULE_XML%') -replace '</resources>', ^
        '  <resource-root path=""./local/%JAR_NAME%"" />^
  </resources>' | Set-Content '%MODULE_XML%'"
    echo    module.xml updated
) else (
    echo    Already in module.xml, skipping
)

:: 3. Reload JBoss if it is running
echo.
echo =^> Checking JBoss state...
"%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":read-attribute(name=server-state)" >nul 2>&1
if errorlevel 1 (
    echo    JBoss is not running - skipping reload
    echo    Start JBoss and the new JAR will be picked up automatically
) else (
    echo    JBoss is running - reloading...
    "%JBOSS_HOME%\bin\jboss-cli.bat" --connect --command=":reload"
    echo    Reload triggered
)

echo.
echo =^> Deploy complete
endlocal
