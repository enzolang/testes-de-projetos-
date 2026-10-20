# Deixar só o Windows no SSD e o resto no HD

Para quem tem um SSD pequeno (tipo 100 GB) com o Windows e um HD grande, e vive
tendo que formatar porque o C: enche.

## Dá para deixar *só* o Windows no SSD?

Quase. O que dá para mandar para o HD, e é o que mais enche o SSD:

| O que | Como |
| --- | --- |
| Área de Trabalho, Documentos, Downloads, Imagens, Músicas, Vídeos | o script muda o local delas e move os arquivos |
| Arquivos temporários | o script aponta o TEMP para o HD |
| Programas e jogos novos | você escolhe o HD na hora de instalar (dicas abaixo) |
| Programas e jogos já instalados | o script move a pasta e deixa um link no lugar, sem reinstalar |
| Lixo do Windows (cache do Windows Update, temporários, hibernação) | o script limpa |

O que **não** dá para tirar do SSD: `C:\Windows`, a pasta `AppData` inteira,
`C:\Program Files` e `C:\ProgramData` inteiros. Existem truques para mover essas
pastas, mas a Microsoft não suporta isso: as atualizações grandes do Windows passam
a falhar e o PC acaba precisando ser formatado, que é justamente o que você quer evitar.
Dentro delas, dá para mover pastas específicas (a pasta de um jogo, o cache de um
programa) com a opção 6 do script.

Com o Windows ocupando uns 30 a 40 GB, sobram 60 GB ou mais no SSD, o que dá e sobra
quando o resto vai para o HD.

## Como usar

1. Faça backup do que for importante (é sempre bom antes de mexer em pastas).
2. Baixe esta pasta (no GitHub: **Code > Download ZIP**) e extraia.
3. Dê dois cliques em **`LIBERAR-SSD.bat`** e clique em **Sim** no aviso de administrador.
   Se aparecer "O Windows protegeu o computador", clique em **Mais informações > Executar assim mesmo**.
4. Digite a letra do HD (o script lista os discos e avisa se você escolher um que fica no mesmo SSD).
5. No menu:
   - **1** mostra o que está enchendo o SSD.
   - **8** faz o recomendado de uma vez: move as pastas pessoais, manda os temporários para o HD e limpa o SSD.
   - **5** desliga a hibernação (o arquivo `hiberfil.sys` costuma ter de 3 a 12 GB).
   - **6** move a pasta de um programa/jogo já instalado (veja as maiores pastas na opção 1).
   - **9** mostra como instalar coisas novas direto no HD.
6. Reinicie o PC no final.

## O que cada opção faz

1. **Relatório**: mostra o tamanho de `hiberfil.sys` e `pagefile.sys`, das pastas pessoais, do lixo que
   dá para limpar e das maiores pastas em Program Files, ProgramData e AppData.
2. **Pastas pessoais**: faz o mesmo que *Propriedades > Local > Mover* do Windows, para as 6 pastas,
   e move tudo para `D:\Usuarios\<seu usuário>\`. Pula pastas que estão no OneDrive (desligue o
   backup do OneDrive para elas antes). Se algum arquivo estava aberto, ele fica para trás; rode de
   novo para terminar.
3. **Temporários**: muda as variáveis `TEMP`/`TMP` da sua conta para `D:\Temp\<seu usuário>` e limpa a
   pasta antiga. Rodar de novo oferece voltar ao padrão.
4. **Limpeza**: apaga temporários e o cache de downloads do Windows Update, esvazia a Lixeira (pergunta
   antes), roda a limpeza de componentes do Windows (DISM, pergunta antes) e liga o Sensor de
   Armazenamento para limpar temporários sozinho toda semana. Se existir `Windows.old`, explica como apagar.
5. **Hibernação**: `powercfg /hibernate off`. Some a opção "Hibernar" e a "Inicialização rápida".
   Para voltar: Prompt de Comando como administrador, `powercfg /h on`.
6. **Mover pasta com link**: move, por exemplo, `C:\Program Files\MeuJogo` para
   `D:\MovidoDoSSD\Program Files\MeuJogo` e cria um link (junção) no lugar. O programa continua
   funcionando sem reinstalar. Cuidados que o script toma:
   - recusa pastas do Windows/Microsoft e pastas inteiras como `Program Files` ou `AppData`;
   - antes de tudo renomeia a pasta, então se o programa estiver aberto ele para sem mexer em nada;
   - copia, confere se chegou tudo (quantidade de arquivos e bytes) e só então apaga do SSD;
   - se algo der errado no meio, volta tudo como estava.
   A lista do que foi movido fica em `D:\MovidoDoSSD\pastas-movidas.txt`.
7. **Trazer de volta**: desfaz a opção 6 para uma pasta.

## Daqui para frente: instalar no HD

- **Programas**: na instalação, clique em *Procurar/Alterar* e use `D:\Programas\NomeDoPrograma`.
- **Steam**: *Configurações > Armazenamento > Adicionar unidade* e deixe o HD como padrão.
  Jogos já instalados têm o botão *Mover*.
- **Epic Games**: troque a pasta na hora de instalar.
- **Microsoft Store / app Xbox**: *Configurações > Sistema > Armazenamento > Configurações de
  armazenamento avançadas > Onde o novo conteúdo é salvo*.

O HD é bem mais lento que o SSD. Vale deixar no SSD o jogo que você mais joga e os programas que usa
todo dia; o resto vai para o HD.

## O que evitar

- Mover `C:\Users`, `C:\Program Files` ou `C:\ProgramData` inteiros, ou mudar o `ProgramFilesDir` no
  registro: quebra as atualizações do Windows.
- Mover o `pagefile.sys` para o HD: deixa o PC lento quando a memória enche.
- Apagar coisas da pasta `C:\Windows\WinSxS` na mão: use a limpeza (opção 4).
- Se o seu HD for **externo (USB)**, pense bem: com ele desconectado, as pastas e programas que estão
  nele somem e os temporários param de funcionar. O script avisa se detectar isso.

## Como desfazer

- **Pastas pessoais**: botão direito na pasta > *Propriedades > Local > Restaurar Padrão*.
- **Temporários**: rode a opção 3 de novo e aceite voltar para o padrão.
- **Pasta movida com link**: opção 7.
- **Hibernação**: `powercfg /h on` num Prompt de Comando como administrador.
