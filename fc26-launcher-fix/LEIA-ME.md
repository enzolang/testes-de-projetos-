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
4. Na linha `LOJA`, deixe `STEAM` se comprou na Steam, ou troque para `EA` se
   comprou no EA app. Salve.
5. Abra com duplo clique, **sem** "Executar como administrador". A Steam, o EA
   app e o jogo precisam rodar no mesmo nível para a licença passar de um para
   o outro.

O script:

1. fecha o FC 26 e o EA app se estiverem travados (sem mexer nos serviços de
   fundo do EA);
2. pergunta se você quer limpar o cache do EA app e mostra onde fica;
3. abre a Steam (e deixa ela abrir o EA app) ou, se `LOJA=EA`, abre o EA app;
4. abre o jogo pelo programa do mod.

## Diagnóstico: `diagnostico_fc26.bat`

Se aparecer "jogo não instalado" ou "ocorreu um erro, reinicie", rode o
`diagnostico_fc26.bat`. Ele não muda nada no PC, só procura onde o FC 26 está
instalado e o que o Windows registrou sobre ele. No fim ele abre o
`diagnostico_fc26.txt` no Bloco de Notas, para você copiar e mandar.

O relatório mostra o nome da sua pasta de usuário do Windows. Se não quiser
mostrar, troque o nome antes de mandar.

## Steam: "Falha ao iniciar o jogo. Um erro em nossos sistemas..."

É um erro conhecido do FC 26 da Steam, que aparece na hora em que a Steam
passa o jogo para o EA app. A EA não tem uma correção oficial para ele.
Siga na ordem:

1. **Teste sem mod.** Feche tudo. Na Steam: FC 26 > Propriedades > Geral >
   *Opções de inicialização*: apague tudo o que tiver lá (por exemplo
   `-dataPath FIFAModData`). Depois: Propriedades > Arquivos instalados >
   *Verificar integridade*. Clique em **Jogar** na própria Steam e deixe ela
   abrir o EA app sozinha.
   - **Abriu sem mod**: a Steam e o EA app estão bons, o problema é o jeito
     que o mod abre o jogo. Vá para o passo 3.
   - **Não abriu nem sem mod**: vá para o passo 2.
2. **Conta e EA app** (o jogo não abre nem sem mod):
   - No EA app, saia da conta (*Sair*) e entre de novo com a conta EA que
     está ligada à sua Steam. Se você tem duas contas EA, esse costuma ser o
     problema.
   - Reinicie o PC, limpe o cache do EA app (App Recovery) e repare ou
     reinstale o EA Javelin Anticheat.
   - Se ainda não abrir, só o suporte da EA consegue resolver: abra um
     chamado em help.ea.com e informe que é a versão da Steam e a mensagem
     exata do erro.
3. **Mod** (o jogo abre sem mod, mas não com mod):
   - Desde a atualização 1.3.0 do FC 26, o FIFA Mod Manager sozinho não
     consegue abrir o jogo. Instale o FC 26 Live Editor (versão 26.2.0 ou
     mais nova) e, no Mod Manager, clique na seta ao lado de *Launch* e ligue
     a opção de abrir o Live Editor junto.
   - Reinstale o mod do FIFA Mania se o jogo atualizou depois que você
     instalou o mod.

## "Jogo não instalado", mas está instalado

- **Comprou na Steam**: abra a Steam antes de tudo. A cópia da Steam abre
  pela Steam, e o EA app sozinho pode achar que o jogo não está instalado.
  Na Steam, use *Verificar integridade dos arquivos*.
- **Comprou no EA app e o jogo está em outra pasta ou outro disco**: o EA app
  só procura na pasta onde ele instala. Nas configurações de download do EA
  app, coloque como local de instalação a pasta que tem a pasta
  `EA SPORTS FC 26` dentro. Depois clique em *Instalar*: ele confere os
  arquivos que já existem em vez de baixar tudo de novo.
- **Quem reclama é o programa do mod**: esses programas descobrem onde o jogo
  está pelo registro do Windows. Rode *Reparar* no EA app (ou *Verificar
  integridade* na Steam) e tente de novo. Se o programa tiver opção de
  escolher a pasta do jogo, aponte para a pasta que o diagnóstico mostrou.

## "Ocorreu um erro, reinicie"

- Reinicie o PC de verdade, não só o EA app. O anticheat (EA Javelin) instala
  um driver que só funciona depois de reiniciar.
- Depois limpe o cache do EA app (App Recovery).
- Se continuar, repare ou reinstale o EA Javelin Anticheat e rode *Reparar*
  no FC 26.

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
