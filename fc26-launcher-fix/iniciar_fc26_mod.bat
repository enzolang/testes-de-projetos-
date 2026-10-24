@echo off
setlocal
title FC 26 com mod - inicializador

rem ============================================================
rem  CONFIGURE AQUI
rem
rem  MOD_LAUNCHER: o programa que voce usa para abrir o jogo com
rem  o mod (FIFA Mod Manager, launcher do FCM, etc).
rem  Dica: botao direito no atalho > "Abrir local do arquivo".
rem
rem  LOJA: onde voce comprou o jogo, STEAM ou EA.
rem ============================================================
set "MOD_LAUNCHER=C:\CAMINHO\PARA\ModManager.exe"
set "LOJA=STEAM"

rem Rode este arquivo normalmente (duplo clique), NAO como
rem administrador: a Steam, o EA app e o jogo precisam rodar
rem no mesmo nivel para passar a licenca de um para o outro.

set "EA_APP=%ProgramFiles%\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe"

echo [1/4] Fechando o jogo e o EA app que ficaram travados...
for %%P in (FC26.exe EADesktop.exe) do (
    taskkill /F /IM %%P >nul 2>&1
)
timeout /t 3 /nobreak >nul

echo.
choice /C SN /M "[2/4] Quer limpar o cache do EA app? (recomendado se ele trava em Preparando jogo)"
if errorlevel 2 goto :abrir_loja
echo.
echo   Abra: Iniciar ^> Todos os aplicativos ^> pasta EA ^> App Recovery ^> Limpar cache.
echo   Quando terminar, volte aqui.
pause

:abrir_loja
echo.
if /I "%LOJA%"=="EA" goto :abrir_ea

echo [3/4] Abrindo a Steam...
start "" "steam://open/main"
echo.
echo   Espere a Steam abrir e estar logada.
echo   NAO abra o EA app: a Steam abre ele sozinha quando o jogo iniciar.
echo   Se o EA app pedir login, use a conta EA ligada a sua Steam.
pause
goto :abrir_mod

:abrir_ea
echo [3/4] Abrindo o EA app...
if not exist "%EA_APP%" goto :sem_ea
start "" "%EA_APP%"
goto :esperar_ea

:sem_ea
echo   Nao achei o EA app em:
echo   "%EA_APP%"
echo   Abra o EA app manualmente.

:esperar_ea
echo.
echo   Espere o EA app abrir por completo e fazer login.
echo   NAO clique em Jogar no EA app, o jogo vai abrir pelo mod.
pause

:abrir_mod
echo.
echo [4/4] Abrindo o jogo com o mod...
if not exist "%MOD_LAUNCHER%" goto :sem_mod
for %%I in ("%MOD_LAUNCHER%") do start "" /D "%%~dpI" "%%~fI"
echo   Pronto. Pode fechar esta janela.
timeout /t 5 >nul
exit /b 0

:sem_mod
echo   Nao achei o programa do mod em:
echo   "%MOD_LAUNCHER%"
echo   Edite a linha MOD_LAUNCHER no topo deste arquivo
echo   ^(botao direito ^> Editar^) e coloque o caminho certo.
pause
exit /b 1
