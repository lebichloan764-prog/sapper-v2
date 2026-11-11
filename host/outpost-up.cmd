@echo off
setlocal
rem outpost-up.cmd — logon supervisor. Every 30s it asks WSL to ensure the outpost
rem is up: boot.sh exits immediately when the watchdog + session already exist, so
rem this is both the keepalive (WSL idles the distro down after ~60s idle, which
rem would kill every worker pane) and the supervisor.
if /i "%~1"=="loop" goto loop
start "" /min cmd /c ""%~f0" loop"
exit /b

:loop
wsl.exe -d Ubuntu -e bash -lc "bash /root/sapper/repo/host/boot.sh --minutes 240" >nul 2>&1
timeout /t 30 >nul
goto loop
