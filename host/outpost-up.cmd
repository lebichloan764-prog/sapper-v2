@echo off
setlocal
rem outpost-up.cmd — logon hook. Keeps the WSL VM from idling down and keeps the
rem outpost service alive. Runs a 30s heartbeat loop (shorter than WSL's 60s idle
rem timeout) in a minimised window; `outpost-up.cmd loop` is the loop body.
if /i "%~1"=="loop" goto loop
start "" /min cmd /c ""%~f0" loop"
exit /b

:loop
wsl.exe -d Ubuntu -e bash -lc "systemctl is-active sapper-outpost.service >/dev/null || systemctl start sapper-outpost.service"
timeout /t 30 >nul
goto loop
