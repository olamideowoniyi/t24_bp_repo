@echo off
setlocal

:: ── Environment (adjust these if paths differ) ────────────────
set TAFJ_HOME=C:\R25\TAFJ
set BNK_HOME=C:\R25\bnk
set T24_LIB=%BNK_HOME%\t24lib
set T24_LOCAL=%BNK_HOME%\local
set JAVA_HOME=C:\R25\TAFJ\eclipse\jre

:: ── Build output ───────────────────────────────────────────────
set BUILD_DIR=%TEMP%\tafj-build-%RANDOM%
set BP_DIR=%~dp0..\bp

echo.
echo =^> Starting T24 BASIC compilation
echo =^> Source  : %BP_DIR%
echo =^> t24lib  : %T24_LIB%
echo =^> Output  : %T24_LOCAL%
echo.

if not exist "%T24_LOCAL%" mkdir "%T24_LOCAL%"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Build classpath from t24lib JARs + TAFJClient
set CLASSPATH=%TAFJ_HOME%\lib\TAFJClient.jar
for %%J in ("%T24_LIB%\*.jar") do set CLASSPATH=!CLASSPATH!;%%J

:: Compile each .b file found in bp/
set COMPILED=0
for %%F in ("%BP_DIR%\*.b") do (
    echo    Compiling: %%~nxF
    call "%TAFJ_HOME%\bin\tCompile.bat" ^
        -tafj "%TAFJ_HOME%" ^
        -classpath "%CLASSPATH%" ^
        -d "%BUILD_DIR%" ^
        "%%F"
    if errorlevel 1 (
        echo ERROR: Failed to compile %%~nxF
        exit /b 1
    )
    set /a COMPILED+=1
)

if %COMPILED%==0 (
    echo No .b files found in %BP_DIR%
    exit /b 1
)

:: Package all compiled classes into one JAR named after the repo
echo.
echo =^> Packaging into local-bp.jar
jar cf "%T24_LOCAL%\local-bp.jar" -C "%BUILD_DIR%" .
if errorlevel 1 (
    echo ERROR: JAR packaging failed
    exit /b 1
)

echo =^> Compiled %COMPILED% file(s) successfully
echo =^> JAR: %T24_LOCAL%\local-bp.jar

:: Cleanup
rmdir /s /q "%BUILD_DIR%"
endlocal
