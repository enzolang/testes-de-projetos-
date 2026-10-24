@echo off
setlocal
title FC 26 - diagnostico

rem Este arquivo so le informacoes, nao muda nada no PC.

set "EA_APP=%ProgramFiles%\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe"
set "RELATORIO=%~dp0diagnostico_fc26.txt"

echo Coletando informacoes, aguarde...
call :relatorio > "%RELATORIO%" 2>&1
echo Pronto. O relatorio foi salvo em:
echo "%RELATORIO%"
start "" notepad "%RELATORIO%"
timeout /t 5 >nul
exit /b 0

:relatorio
echo ===== Diagnostico FC 26 =====
echo Data: %date% %time%
ver
echo.

echo --- Rodando como administrador? ---
net session >nul 2>&1 && echo Sim || echo Nao
echo.

echo --- EA app ---
if exist "%EA_APP%" echo Encontrado: "%EA_APP%"
if not exist "%EA_APP%" echo NAO encontrado em: "%EA_APP%"
echo.

echo --- Steam ---
reg query "HKCU\Software\Valve\Steam" /v SteamPath
echo.

echo --- Pastas do FC 26 encontradas ---
for %%D in (C D E F G H I J) do (
    for %%F in ("%%D:\Program Files\EA Games\EA SPORTS FC 26" "%%D:\EA Games\EA SPORTS FC 26" "%%D:\Program Files (x86)\Steam\steamapps\common\EA SPORTS FC 26" "%%D:\Steam\steamapps\common\EA SPORTS FC 26" "%%D:\SteamLibrary\steamapps\common\EA SPORTS FC 26") do (
        if exist "%%~F\*" (
            echo ENCONTRADO: %%~F
            dir /b "%%~F\*.exe"
            echo.
        )
    )
)
echo (fim da busca de pastas)
echo.

echo --- Registro do Windows: EA Sports ---
reg query "HKLM\SOFTWARE\EA Sports" /s
reg query "HKLM\SOFTWARE\WOW6432Node\EA Sports" /s
echo.

echo --- Programas do EA e do jogo abertos agora ---
tasklist | findstr /I /B "EA FC2"
echo.

echo --- Servicos do EA ---
sc query EABackgroundService
sc query EAAntiCheatService
echo.

echo --- Ultimos erros de programas no Windows ---
wevtutil qe Application /q:"*[System[(Level=1 or Level=2)]]" /c:15 /rd:true /f:text
echo.
echo ===== Fim =====
exit /b 0
