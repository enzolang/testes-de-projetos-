@echo off
setlocal
title FC 26 com mod - inicializador

rem ============================================================
rem  CONFIGURE AQUI: o programa que voce usa para abrir o jogo
rem  com o mod (FIFA Mod Manager, launcher do FCM, etc).
rem  Dica: botao direito no atalho > "Abrir local do arquivo".
rem ============================================================
set "MOD_LAUNCHER=C:\CAMINHO\PARA\ModManager.exe"

set "EA_APP=%ProgramFiles%\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe"

net session >nul 2>&1
if errorlevel 1 (
    echo AVISO: rode este arquivo como administrador
    echo        ^(botao direito ^> Executar como administrador^).
    echo.
)

echo [1/4] Fechando o jogo e o EA app que ficaram travados...
for %%P in (FC26.exe EADesktop.exe EABackgroundService.exe EALocalHostSvc.exe) do (
    taskkill /F /IM %%P >nul 2>&1
)
timeout /t 3 /nobreak >nul

echo.
choice /C SN /M "[2/4] Quer limpar o cache do EA app? (recomendado se ele trava em Preparando jogo)"
if errorlevel 2 goto :abrir_ea
echo.
echo   Abra: Iniciar ^> Todos os aplicativos ^> pasta EA ^> App Recovery ^> Limpar cache.
echo   Quando terminar, volte aqui.
pause

:abrir_ea
echo.
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
