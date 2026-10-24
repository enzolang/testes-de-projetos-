# FC 26 com mod: corrigir o launcher do EA app

## Por que não dá para pular o EA app

O EA app é quem confere a licença do FC 26, e o anticheat (Javelin) também
depende dele. Sem o EA app aberto o jogo não inicia, mesmo comprado pela
Steam. A única forma de "pular" o EA app é crackear o jogo, e isso este
arquivo não faz.

O que dá para fazer é deixar o EA app abrir direito antes do jogo, que é onde
a maioria dos problemas acontece (o jogo fica em "Preparando jogo", fecha
sozinho ou volta para o EA app).

## Como usar o `iniciar_fc26_mod.bat`

1. Baixe o arquivo `iniciar_fc26_mod.bat`.
2. Clique com o botão direito nele > **Editar**.
3. Troque `C:\CAMINHO\PARA\ModManager.exe` pelo caminho do programa que você
   usa para abrir o jogo com o mod (Mod Manager ou o launcher do FIFA Mania).
   Salve.
4. Clique com o botão direito > **Executar como administrador**.

O script:

1. fecha o FC 26 e o EA app se estiverem travados;
2. pergunta se você quer limpar o cache do EA app e mostra onde fica;
3. abre o EA app e espera você fazer login;
4. abre o jogo pelo programa do mod.

## Se ainda não funcionar

Faça um item por vez e teste:

- **Limpar cache do EA app**: Iniciar > Todos os aplicativos > pasta EA >
  App Recovery > Limpar cache.
- **Mesmo disco**: deixe o Mod Manager e o mod no mesmo disco (C:, D:...)
  em que o FC 26 está instalado.
- **Opções de inicialização**: se você colocou `-dataPath FIFAModData` nas
  opções de inicialização da Steam ou do EA app, apague. O Mod Manager já
  faz isso sozinho.
- **Live Editor**: no Mod Manager, clique na seta ao lado de *Launch* e
  escolha a opção com *Live Editor*. Teve gente que só conseguiu abrir assim.
- **Antivírus**: o Windows Defender pode achar que o Mod Manager é ameaça e
  fechar o jogo. Coloque a pasta do jogo e a do Mod Manager nas exclusões.
- **Modo offline**: deixe o EA app em modo offline para jogar carreira com
  mod.
- **Depois de atualização do jogo**: o mod do FIFA Mania precisa ser
  reinstalado a cada atualização do FC 26. Se o jogo atualizou, reinstale o
  mod antes de abrir.
- **Testar sem mod**: abra o FC 26 pelo EA app sem mod. Se nem assim abrir,
  o problema é do jogo ou do EA app: use *Reparar* no EA app.

## Aviso

Use o mod só nos modos offline (carreira, amistoso). Entrar no Ultimate Team
ou Clubs com mod pode dar banimento da conta.
