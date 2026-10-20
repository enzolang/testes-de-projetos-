@echo off
rem Abre o liberar-ssd.ps1. Ele mesmo pede permissao de administrador.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0liberar-ssd.ps1"
if errorlevel 1 pause
