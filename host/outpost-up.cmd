@echo off
rem outpost-up.cmd — Windows logon hook: bring the WSL legion up.
wsl.exe -d Ubuntu -e bash -lc "systemctl is-active sapper-outpost.service >/dev/null || systemctl start sapper-outpost.service"
