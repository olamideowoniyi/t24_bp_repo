@echo off
setlocal enabledelayedexpansion
set BP_DIR=C:\t24-local-bp\bp
set COMPILED=0
for %%F in (%BP_DIR%\*.b) do (
    echo Found: %%F
    set /a COMPILED+=1
)
echo Total compiled: !COMPILED!
