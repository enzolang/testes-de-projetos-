<#
    liberar-ssd.ps1

    Deixa só o Windows no SSD e manda o resto para o HD:
      - Área de Trabalho, Documentos, Downloads, Imagens, Músicas e Vídeos
      - arquivos temporários
      - pastas de programas/jogos já instalados (movidas com link, sem reinstalar)
    e ainda limpa o que o Windows vai acumulando no SSD.

    Como usar: dê dois cliques em LIBERAR-SSD.bat.
    O script pede permissão de administrador e mostra um menu.
#>

# ---------------------------------------------------------------------------
# Precisa rodar como administrador
# ---------------------------------------------------------------------------
$identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
$ehAdmin = (New-Object Security.Principal.WindowsPrincipal $identidade).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $ehAdmin) {
    Write-Host 'Pedindo permissão de administrador...'
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    } catch {
        Write-Host 'Sem permissão de administrador o script não consegue continuar.' -ForegroundColor Red
        Read-Host 'Pressione Enter para sair' | Out-Null
    }
    exit
}

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Liberar espaço no SSD'

$Sistema        = $env:SystemDrive          # normalmente C:
$LetraSistema   = $Sistema.Substring(0, 1)
$Script:Destino = $null                     # letra do HD, ex.: D:  (escolhida no início)

$PastasPessoais = @(
    [pscustomobject]@{ Nome = 'Área de Trabalho'; Id = [guid]'B4BFCC3A-DB2C-424C-B029-7FE99A87C641' }
    [pscustomobject]@{ Nome = 'Documentos';       Id = [guid]'FDD39AD0-238F-46AF-ADB4-6C85480369C7' }
    [pscustomobject]@{ Nome = 'Downloads';        Id = [guid]'374DE290-123F-4565-9164-39C4925E467B' }
    [pscustomobject]@{ Nome = 'Imagens';          Id = [guid]'33E28130-4E1E-4676-835A-98395C3BC3BB' }
    [pscustomobject]@{ Nome = 'Músicas';          Id = [guid]'4BD8D571-6D19-48D3-BE97-422220080E43' }
    [pscustomobject]@{ Nome = 'Vídeos';           Id = [guid]'18989B1D-99B5-455B-841C-AB7C74E4DDFC' }
)

# Mesma API que o Windows usa na aba "Local" das propriedades da pasta.
if (-not ('PastasConhecidas' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class PastasConhecidas
{
    [DllImport("shell32.dll")]
    private static extern int SHGetKnownFolderPath(ref Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr ppszPath);

    [DllImport("shell32.dll")]
    private static extern int SHSetKnownFolderPath(ref Guid rfid, uint dwFlags, IntPtr hToken,
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath);

    public static string Obter(Guid id)
    {
        IntPtr ptr;
        int hr = SHGetKnownFolderPath(ref id, 0, IntPtr.Zero, out ptr);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        try { return Marshal.PtrToStringUni(ptr); }
        finally { Marshal.FreeCoTaskMem(ptr); }
    }

    public static void Definir(Guid id, string caminho)
    {
        int hr = SHSetKnownFolderPath(ref id, 0, IntPtr.Zero, caminho);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
    }
}
'@
}

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------
function Escrever-Titulo([string]$Texto) {
    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host "  $Texto" -ForegroundColor Cyan
    Write-Host ('=' * 64) -ForegroundColor Cyan
}

function Avisar([string]$Texto) { Write-Host $Texto -ForegroundColor Yellow }
function Erro([string]$Texto)   { Write-Host $Texto -ForegroundColor Red }
function Ok([string]$Texto)     { Write-Host $Texto -ForegroundColor Green }

function Formatar-Tamanho([double]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    return '{0:N0} KB' -f ($Bytes / 1KB)
}

function Linha([double]$Bytes, [string]$Texto) {
    Write-Host ('  {0,10}  {1}' -f (Formatar-Tamanho $Bytes), $Texto)
}

function Confirmar([string]$Pergunta) {
    return (Read-Host "$Pergunta [s/n]") -match '^\s*s'
}

function Pausar { Read-Host "`nPressione Enter para voltar ao menu" | Out-Null }

function Espaco-Livre([string]$Letra) {
    return (New-Object IO.DriveInfo $Letra.Substring(0, 1)).AvailableFreeSpace
}

# $Caminho é a própria $Base ou está dentro dela?
function Esta-Dentro([string]$Caminho, [string]$Base) {
    $Caminho = $Caminho.TrimEnd('\')
    $Base = $Base.TrimEnd('\')
    return $Caminho.Equals($Base, [StringComparison]::OrdinalIgnoreCase) -or
           $Caminho.StartsWith($Base + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Obter-Disco([string]$Letra) {
    try { return Get-Partition -DriveLetter $Letra -ErrorAction Stop | Get-Disk -ErrorAction Stop }
    catch { return $null }
}

# Soma o tamanho de uma pasta sem entrar em links (junções/symlinks).
# TemLinks avisa se existe alguma pasta-link lá dentro.
function Medir-Pasta([string]$Caminho, [string[]]$IgnorarNomes = @()) {
    $resultado = [pscustomobject]@{ Bytes = [int64]0; Arquivos = 0; TemLinks = $false }
    if (-not $Caminho -or -not (Test-Path -LiteralPath $Caminho -PathType Container)) { return $resultado }
    $pilha = New-Object 'System.Collections.Generic.Stack[System.IO.DirectoryInfo]'
    $pilha.Push((New-Object IO.DirectoryInfo $Caminho))
    while ($pilha.Count -gt 0) {
        $pasta = $pilha.Pop()
        try { $filhos = $pasta.GetFileSystemInfos() } catch { continue }
        foreach ($f in $filhos) {
            if ($f -is [IO.DirectoryInfo]) {
                if ($f.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { $resultado.TemLinks = $true }
                else { $pilha.Push($f) }
            } elseif ($IgnorarNomes -notcontains $f.Name) {
                $resultado.Bytes += $f.Length
                $resultado.Arquivos++
            }
        }
    }
    return $resultado
}

# Apaga o conteúdo de uma pasta (e a própria pasta, com -IncluirPasta) sem nunca
# entrar em links: o link some, mas o que ele aponta fica intacto.
# Arquivos em uso são pulados. Devolve quantos bytes foram liberados.
function Apagar-Arvore([string]$Caminho, [switch]$IncluirPasta) {
    $liberado = [int64]0
    if (-not (Test-Path -LiteralPath $Caminho -PathType Container)) { return $liberado }
    $raiz = New-Object IO.DirectoryInfo $Caminho
    $itens = New-Object 'System.Collections.Generic.List[System.IO.FileSystemInfo]'
    $pilha = New-Object 'System.Collections.Generic.Stack[System.IO.DirectoryInfo]'
    $pilha.Push($raiz)
    while ($pilha.Count -gt 0) {
        $pasta = $pilha.Pop()
        try { $filhos = $pasta.GetFileSystemInfos() } catch { continue }
        foreach ($f in $filhos) {
            $itens.Add($f)
            if ($f -is [IO.DirectoryInfo] -and -not $f.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
                $pilha.Push($f)
            }
        }
    }
    if ($IncluirPasta) { $itens.Insert(0, $raiz) }
    # De trás para frente: o conteúdo de cada pasta sai antes da própria pasta.
    for ($i = $itens.Count - 1; $i -ge 0; $i--) {
        $item = $itens[$i]
        try {
            if ($item.Attributes.HasFlag([IO.FileAttributes]::ReadOnly)) {
                $item.Attributes = $item.Attributes -bxor [IO.FileAttributes]::ReadOnly
            }
            $tamanho = if ($item -is [IO.FileInfo]) { $item.Length } else { 0 }
            $item.Delete()
            $liberado += $tamanho
        } catch { }
    }
    return $liberado
}

# Trava de segurança: só limpa pastas "Temp" e o cache de downloads do Windows Update.
function Limpar-Pasta([string]$Caminho) {
    $Caminho = $Caminho.TrimEnd('\')
    $permitido = ([IO.Path]::GetFileName($Caminho) -eq 'Temp') -or
                 ($Caminho -eq "$env:SystemRoot\SoftwareDistribution\Download")
    if (-not $permitido) {
        Avisar "  (pulando $Caminho por segurança)"
        return [int64]0
    }
    return Apagar-Arvore $Caminho
}

# Devolve o código do robocopy: 0 a 7 = ok, 8 ou mais = algum arquivo falhou.
function Robocopy-Copiar([string]$De, [string]$Para, [switch]$Mover, [switch]$SemSobrescrever) {
    $De = $De.TrimEnd('\')
    $Para = $Para.TrimEnd('\')
    if ($De.Length -le 3 -or $Para.Length -le 3) { throw 'Robocopy-Copiar não trabalha com a raiz de um disco.' }
    $argumentos = @($De, $Para, '/E', '/COPY:DAT', '/DCOPY:DAT', '/XJD', '/R:1', '/W:1',
                    '/NP', '/NFL', '/NDL', '/NJH', '/NJS')
    if ($Mover) { $argumentos += '/MOVE' }
    # Nunca sobrescreve um arquivo que já existe no destino.
    if ($SemSobrescrever) { $argumentos += @('/XC', '/XN', '/XO') }
    & robocopy.exe @argumentos | Out-Null
    return $LASTEXITCODE
}

# Deixa a pasta só para você (como é a sua pasta em C:\Users).
function Proteger-Pasta([string]$Caminho) {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $Caminho /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
}

# Onde a opção 6 guarda uma pasta: C:\Program Files\Jogo -> D:\MovidoDoSSD\Program Files\Jogo
function Caminho-NoHD([string]$Origem) {
    return Join-Path "$Script:Destino\MovidoDoSSD" $Origem.Substring(3)
}

function Ler-Caminho([string]$Pergunta) {
    $entrada = Read-Host $Pergunta
    $entrada = [Environment]::ExpandEnvironmentVariables($entrada.Trim().Trim('"'))
    if (-not $entrada) { return $null }
    if (-not [IO.Path]::IsPathRooted($entrada)) {
        Erro 'Digite o caminho completo, ex.: C:\Program Files\MeuJogo'
        return $null
    }
    return [IO.Path]::GetFullPath($entrada).TrimEnd('\')
}

# ---------------------------------------------------------------------------
# Escolher o HD
# ---------------------------------------------------------------------------
function Escolher-Destino {
    Escrever-Titulo 'Qual é o seu HD?'
    $discoSistema = Obter-Disco $LetraSistema
    $opcoes = @([IO.DriveInfo]::GetDrives() | Where-Object {
        $_.IsReady -and ($_.DriveType -eq 'Fixed' -or $_.DriveType -eq 'Removable') -and
        $_.Name.Substring(0, 1) -ne $LetraSistema
    })
    if ($opcoes.Count -eq 0) {
        Erro "Não achei nenhum outro disco além do $Sistema."
        Write-Host 'Se o HD é novo, talvez ele precise ser inicializado e formatado no "Gerenciamento de Disco"'
        Write-Host '(botão direito no menu Iniciar > Gerenciamento de Disco).'
        return $false
    }

    Write-Host 'Discos encontrados:'
    foreach ($d in $opcoes) {
        $letra = $d.Name.Substring(0, 1)
        $disco = Obter-Disco $letra
        $modelo = if ($disco) { "$($disco.FriendlyName) [$($disco.BusType)]" } else { '' }
        $mesmo = if ($discoSistema -and $disco -and $disco.Number -eq $discoSistema.Number) { '  <- mesmo disco do Windows!' } else { '' }
        Write-Host ('  {0}:  {1,-14} {2,-6} livre {3,9} de {4,9}   {5}{6}' -f $letra, $d.VolumeLabel, $d.DriveFormat,
            (Formatar-Tamanho $d.AvailableFreeSpace), (Formatar-Tamanho $d.TotalSize), $modelo, $mesmo)
    }

    while ($true) {
        $letra = (Read-Host "`nDigite a letra do HD (ex.: D)").Trim().TrimEnd(':', '\').ToUpper()
        $escolhido = $opcoes | Where-Object { $_.Name.Substring(0, 1) -eq $letra } | Select-Object -First 1
        if (-not $escolhido) { Erro 'Letra inválida.'; continue }

        $disco = Obter-Disco $letra
        if ($discoSistema -and $disco -and $disco.Number -eq $discoSistema.Number) {
            Erro "${letra}: fica no mesmo disco físico do Windows (o SSD). Mover para lá não libera espaço."
            continue
        }
        if ($escolhido.DriveFormat -ne 'NTFS') {
            Avisar "${letra}: está formatado em $($escolhido.DriveFormat). O recomendado é NTFS (sem NTFS a opção 6 não funciona)."
            if (-not (Confirmar 'Usar mesmo assim?')) { continue }
        }
        if (($disco -and $disco.BusType -eq 'USB') -or $escolhido.DriveType -eq 'Removable') {
            Avisar 'Esse disco parece ser EXTERNO (USB). Se ele estiver desconectado, as pastas e programas'
            Avisar 'que estão nele somem até você conectar de novo, e alguns programas vão dar erro.'
            if (-not (Confirmar 'Usar mesmo assim?')) { continue }
        }
        $Script:Destino = "${letra}:"
        return $true
    }
}

# ---------------------------------------------------------------------------
# 1) Relatório
# ---------------------------------------------------------------------------
function Mostrar-MaioresPastas([string]$Raiz, [string[]]$Ignorar, [int]$Quantas = 8) {
    if (-not $Raiz -or -not (Test-Path -LiteralPath $Raiz)) { return }
    Write-Host "`n  $Raiz" -ForegroundColor Yellow
    $lista = foreach ($sub in (Get-ChildItem -LiteralPath $Raiz -Directory -Force -ErrorAction SilentlyContinue)) {
        if ($sub.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { continue }
        if ($Ignorar -contains $sub.FullName) { continue }
        [pscustomobject]@{ Caminho = $sub.FullName; Bytes = (Medir-Pasta $sub.FullName).Bytes }
    }
    $grandes = @($lista | Where-Object { $_.Bytes -ge 100MB } | Sort-Object Bytes -Descending | Select-Object -First $Quantas)
    if ($grandes.Count -eq 0) { Write-Host '    (nada acima de 100 MB)'; return }
    foreach ($g in $grandes) { Linha $g.Bytes $g.Caminho }
}

function Relatorio {
    Escrever-Titulo 'O que está ocupando o SSD'
    Write-Host 'Calculando... pode levar alguns minutos.' -ForegroundColor DarkGray

    Write-Host "`nArquivos do sistema:" -ForegroundColor Yellow
    $descricoes = @{
        'hiberfil.sys' = 'hibernação (a opção 5 remove)'
        'pagefile.sys' = 'memória virtual (melhor deixar no SSD)'
        'swapfile.sys' = 'memória virtual dos apps da Store'
    }
    Get-ChildItem -LiteralPath "$Sistema\" -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $descricoes.ContainsKey($_.Name) } |
        ForEach-Object { Linha $_.Length "$($_.Name) - $($descricoes[$_.Name])" }

    Write-Host "`nPastas pessoais:" -ForegroundColor Yellow
    $caminhosPessoais = @()
    foreach ($p in $PastasPessoais) {
        $c = [PastasConhecidas]::Obter($p.Id)
        $caminhosPessoais += $c
        $onde = if (Esta-Dentro $c $Sistema) { 'no SSD' } else { 'fora do SSD' }
        Linha (Medir-Pasta $c).Bytes "$($p.Nome) ($onde) - $c"
    }

    Write-Host "`nLixo que dá para limpar (opção 4):" -ForegroundColor Yellow
    $lixo = [ordered]@{
        'Temporários do usuário'       = "$env:LOCALAPPDATA\Temp"
        'Temporários do Windows'       = "$env:SystemRoot\Temp"
        'Cache do Windows Update'      = "$env:SystemRoot\SoftwareDistribution\Download"
        'Lixeira'                      = "$Sistema\`$Recycle.Bin"
        'Windows antigo (Windows.old)' = "$Sistema\Windows.old"
    }
    foreach ($nome in $lixo.Keys) {
        if (Test-Path -LiteralPath $lixo[$nome]) { Linha (Medir-Pasta $lixo[$nome]).Bytes "$nome - $($lixo[$nome])" }
    }

    Write-Host "`nMaiores pastas (acima de 100 MB):" -ForegroundColor Yellow
    $perfil = $env:USERPROFILE
    $ignorar = @("$perfil\AppData", "$env:LOCALAPPDATA\Temp") + $caminhosPessoais
    foreach ($raiz in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:LOCALAPPDATA, $env:APPDATA, $perfil)) {
        Mostrar-MaioresPastas $raiz $ignorar
    }

    Write-Host ''
    Write-Host 'O que fazer:' -ForegroundColor Cyan
    Write-Host '  - Pastas pessoais no SSD .............................. opção 2'
    Write-Host '  - Temporários, cache do Windows Update, Lixeira ...... opção 4'
    Write-Host '  - hiberfil.sys ........................................ opção 5'
    Write-Host '  - Pastas grandes de programas, jogos e AppData ........ opção 6 (ou reinstale no HD)'
    Write-Host 'Para ver tudo em detalhe, o programa gratuito WizTree mostra o disco inteiro em segundos.'
}

# ---------------------------------------------------------------------------
# 2) Pastas pessoais
# ---------------------------------------------------------------------------
function Mover-PastasPessoais {
    Escrever-Titulo 'Mover pastas pessoais para o HD'
    $base = Join-Path $Script:Destino "Usuarios\$env:USERNAME"
    Write-Host "Área de Trabalho, Documentos, Downloads, Imagens, Músicas e Vídeos vão para: $base"
    Write-Host 'É o mesmo que o Windows faz em Propriedades > Local > Mover, só que de uma vez.'
    Avisar 'Feche os programas abertos (navegador, Word, jogos...) antes de continuar.'
    if (-not (Confirmar 'Continuar?')) { return }

    if (-not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
        Proteger-Pasta $base
    }

    foreach ($p in $PastasPessoais) {
        Write-Host ''
        try {
            $atual = [PastasConhecidas]::Obter($p.Id).TrimEnd('\')
            $nome = [IO.Path]::GetFileName($atual)
            $nova = Join-Path $base $nome

            if ($atual -like '*\OneDrive*') {
                Avisar "$($p.Nome): está sendo salva no OneDrive ($atual)."
                Write-Host '  Desligue o backup dessa pasta no OneDrive (Configurações > Sincronização e backup >'
                Write-Host '  Gerenciar backup) e rode esta opção de novo.'
                continue
            }

            if (Esta-Dentro $atual $Script:Destino) {
                Ok "$($p.Nome): já está no HD ($atual)."
                # Se sobrou algo no lugar antigo (de uma vez anterior), termina de mover.
                $antiga = Join-Path $env:USERPROFILE $nome
                if ((Medir-Pasta $antiga -IgnorarNomes 'desktop.ini').Arquivos -gt 0) {
                    Write-Host "  Movendo o que ficou em $antiga ..."
                    $null = Robocopy-Copiar $antiga $atual -Mover -SemSobrescrever
                    $sobrou = Medir-Pasta $antiga -IgnorarNomes 'desktop.ini'
                    if ($sobrou.Arquivos -gt 0) {
                        Avisar "  Ainda ficaram $($sobrou.Arquivos) arquivo(s) em $antiga (abertos ou com o mesmo nome no HD)."
                    }
                }
                continue
            }

            if (-not (Esta-Dentro $atual $Sistema)) {
                Write-Host "$($p.Nome): está em $atual (fora do SSD). Deixando como está."
                continue
            }

            $medida = Medir-Pasta $atual
            if ($medida.Bytes -gt (Espaco-Livre $Script:Destino) - 1GB) {
                Erro "$($p.Nome): não cabe no HD ($(Formatar-Tamanho $medida.Bytes)). Pulando."
                continue
            }

            Write-Host "$($p.Nome): movendo $(Formatar-Tamanho $medida.Bytes) para $nova ..."
            New-Item -ItemType Directory -Path $nova -Force | Out-Null
            [PastasConhecidas]::Definir($p.Id, $nova)
            $codigo = Robocopy-Copiar $atual $nova -Mover -SemSobrescrever
            $sobrou = Medir-Pasta $atual -IgnorarNomes 'desktop.ini'
            if ($sobrou.Arquivos -gt 0) {
                Avisar "  $($sobrou.Arquivos) arquivo(s) ficaram em $atual (provavelmente estavam abertos; robocopy: $codigo)."
                Avisar '  Feche os programas e rode esta opção de novo para terminar de mover.'
            } else {
                Ok '  Pronto.'
            }
        } catch {
            Erro "$($p.Nome): deu erro ($($_.Exception.Message)). Nada mais foi feito com essa pasta."
        }
    }
    Write-Host ''
    Avisar 'Reinicie o computador para todos os programas usarem os lugares novos.'
    Write-Host 'Para desfazer uma pasta: botão direito nela > Propriedades > Local > Restaurar Padrão.'
}

# ---------------------------------------------------------------------------
# 3) Temporários
# ---------------------------------------------------------------------------
function Mover-Temporarios {
    Escrever-Titulo 'Mandar os arquivos temporários para o HD'
    $padrao = "$env:LOCALAPPDATA\Temp"
    $novo = Join-Path $Script:Destino "Temp\$env:USERNAME"
    $atual = [Environment]::GetEnvironmentVariable('TEMP', 'User')

    if ($atual -and (Esta-Dentro $atual $Script:Destino)) {
        Ok "Os temporários já vão para o HD ($atual)."
        if (Confirmar 'Quer voltar para o padrão (no SSD)?') {
            [Environment]::SetEnvironmentVariable('TEMP', $padrao, 'User')
            [Environment]::SetEnvironmentVariable('TMP', $padrao, 'User')
            Ok "Voltou para $padrao. Reinicie o computador."
        }
        return
    }

    Write-Host "Os programas vão passar a criar arquivos temporários em $novo"
    Write-Host '(a pasta do Windows, C:\Windows\Temp, fica onde está e é limpa na opção 4).'
    if (-not (Confirmar 'Continuar?')) { return }

    if (-not (Test-Path -LiteralPath $novo)) {
        New-Item -ItemType Directory -Path $novo -Force | Out-Null
        Proteger-Pasta $novo
    }
    [Environment]::SetEnvironmentVariable('TEMP', $novo, 'User')
    [Environment]::SetEnvironmentVariable('TMP', $novo, 'User')
    Ok "TEMP e TMP agora apontam para $novo"

    Write-Host 'Limpando a pasta temporária antiga...'
    $liberado = Limpar-Pasta $padrao
    Ok "Liberado: $(Formatar-Tamanho $liberado)"
    Avisar 'Reinicie o computador para todos os programas usarem a pasta nova.'
}

# ---------------------------------------------------------------------------
# 4) Limpeza
# ---------------------------------------------------------------------------
function Limpeza {
    Escrever-Titulo 'Limpeza do SSD'
    $antes = Espaco-Livre $LetraSistema

    Write-Host '> Arquivos temporários...'
    foreach ($t in @("$env:LOCALAPPDATA\Temp", "$env:SystemRoot\Temp")) { $null = Limpar-Pasta $t }

    Write-Host '> Cache de downloads do Windows Update...'
    $parados = @()
    foreach ($s in 'wuauserv', 'bits') {
        $servico = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($servico -and $servico.Status -eq 'Running') {
            try { Stop-Service -Name $s -Force; $parados += $s } catch { }
        }
    }
    $null = Limpar-Pasta "$env:SystemRoot\SoftwareDistribution\Download"
    foreach ($s in $parados) { try { Start-Service -Name $s } catch { } }

    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        Write-Host '> Cache de Otimização de Entrega...'
        try { Delete-DeliveryOptimizationCache -Force | Out-Null } catch { }
    }

    if (Confirmar '> Esvaziar a Lixeira?') {
        try { Clear-RecycleBin -DriveLetter $LetraSistema -Force } catch { }
    }

    if (Confirmar '> Limpar componentes antigos do Windows (DISM)? Pode levar de 5 a 20 minutos') {
        Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup' -NoNewWindow -Wait
    }

    Write-Host '> Ligando o Sensor de Armazenamento (limpa temporários sozinho toda semana)...'
    $chave = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy'
    if (-not (Test-Path $chave)) { New-Item -Path $chave -Force | Out-Null }
    New-ItemProperty -Path $chave -Name '01'   -Value 1 -PropertyType DWord -Force | Out-Null  # ligado
    New-ItemProperty -Path $chave -Name '04'   -Value 1 -PropertyType DWord -Force | Out-Null  # apagar temporários
    New-ItemProperty -Path $chave -Name '2048' -Value 7 -PropertyType DWord -Force | Out-Null  # toda semana

    $depois = Espaco-Livre $LetraSistema
    Write-Host ''
    Ok "Espaço liberado no SSD: $(Formatar-Tamanho ([math]::Max(0, $depois - $antes)))"

    if (Test-Path -LiteralPath "$Sistema\Windows.old") {
        Write-Host ''
        Avisar "Existe a pasta $Sistema\Windows.old (o Windows anterior, costuma ter 10 GB ou mais)."
        Write-Host 'Para apagar: Configurações > Sistema > Armazenamento > Arquivos temporários >'
        Write-Host 'marque "Instalação(ões) anterior(es) do Windows" > Remover arquivos.'
    }
}

# ---------------------------------------------------------------------------
# 5) Hibernação
# ---------------------------------------------------------------------------
function Desligar-Hibernacao {
    Escrever-Titulo 'Desligar a hibernação'
    $arquivo = Get-ChildItem -LiteralPath "$Sistema\" -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'hiberfil.sys' }
    if (-not $arquivo) { Ok 'A hibernação já está desligada.'; return }

    Write-Host "O arquivo da hibernação (hiberfil.sys) ocupa $(Formatar-Tamanho $arquivo.Length) no SSD."
    Write-Host 'Ao desligar, some a opção "Hibernar" e a "Inicialização rápida"'
    Write-Host '(num SSD a diferença no tempo para ligar o PC é pequena).'
    Write-Host 'Em notebook, a hibernação salva o que está aberto quando a bateria acaba; pense nisso.'
    Write-Host 'Para ligar de novo: Prompt de Comando como administrador > powercfg /h on'
    if (-not (Confirmar 'Desligar a hibernação?')) { return }
    & powercfg.exe /hibernate off
    if ($LASTEXITCODE -eq 0) { Ok "Pronto, $(Formatar-Tamanho $arquivo.Length) liberados." }
    else { Erro 'O powercfg não conseguiu desligar a hibernação.' }
}

# ---------------------------------------------------------------------------
# 6) e 7) Mover pasta com link / trazer de volta
# ---------------------------------------------------------------------------
function Motivo-Bloqueio([string]$Origem) {
    if ($Origem.Length -le 3) { return 'Não dá para mover o disco inteiro.' }
    if (-not (Esta-Dentro $Origem $Sistema)) { return "Só dá para mover pastas que estão no $Sistema." }
    if (-not (Test-Path -LiteralPath $Origem -PathType Container)) { return 'Essa pasta não existe.' }
    if ((Get-Item -LiteralPath $Origem -Force).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        return 'Essa pasta já é um link (talvez já tenha sido movida).'
    }

    $perfil = $env:USERPROFILE
    if ((Split-Path $Origem -Parent).TrimEnd('\') -eq "$Sistema\Users") {
        return 'Não dá para mover a pasta de um usuário inteira.'
    }
    $inteiras = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, "$perfil\AppData",
                  $env:LOCALAPPDATA, $env:APPDATA, "$perfil\AppData\LocalLow", "$env:LOCALAPPDATA\Programs")
    $inteiras += $PastasPessoais | ForEach-Object { [PastasConhecidas]::Obter($_.Id) }
    foreach ($e in $inteiras) {
        if ($e -and $Origem -eq $e.TrimEnd('\')) {
            return 'Essa pasta é grande demais/geral demais. Escolha uma subpasta, ex.: a pasta de um jogo. (Pastas pessoais: opção 2.)'
        }
    }
    $doWindows = @("$Sistema\Windows", "$Sistema\`$", "$Sistema\Recovery", "$Sistema\System Volume Information",
                   "$Sistema\Users\Default", "$Sistema\Users\Public", "$perfil\OneDrive",
                   "$env:ProgramFiles\Windows", "$env:ProgramFiles\Common Files", "$env:ProgramFiles\Microsoft",
                   "$env:ProgramData\Microsoft", "$env:LOCALAPPDATA\Microsoft", "$env:LOCALAPPDATA\Packages",
                   "$env:APPDATA\Microsoft")
    if (${env:ProgramFiles(x86)}) {
        $doWindows += "${env:ProgramFiles(x86)}\Windows", "${env:ProgramFiles(x86)}\Common Files", "${env:ProgramFiles(x86)}\Microsoft"
    }
    foreach ($prefixo in $doWindows) {
        if ($Origem.StartsWith($prefixo, [StringComparison]::OrdinalIgnoreCase)) {
            return 'Essa pasta é do Windows ou da Microsoft e não deve ser movida.'
        }
    }
    return $null
}

function Mover-PastaComLink {
    Escrever-Titulo 'Mover pasta de programa/jogo para o HD (com link)'
    Write-Host 'A pasta vai para o HD e no lugar dela fica um link (junção). O programa continua'
    Write-Host 'achando tudo no mesmo caminho, sem reinstalar.'
    Write-Host 'Bom para: jogos fora da Steam, pastas grandes em AppData, caches (.gradle, npm, pip...).'
    Write-Host 'Dica: a opção 1 mostra as maiores pastas. No Explorer, Shift + botão direito > "Copiar como caminho".'
    $origem = Ler-Caminho "`nCaminho da pasta (Enter para cancelar)"
    if (-not $origem) { return }

    $motivo = Motivo-Bloqueio $origem
    if ($motivo) { Erro $motivo; return }

    $destino = Caminho-NoHD $origem
    Write-Host 'Calculando o tamanho...'
    $medida = Medir-Pasta $origem
    if ($medida.TemLinks) { Erro 'Essa pasta tem links dentro dela. Por segurança o script não mexe nela.'; return }
    if ($medida.Arquivos -eq 0) { Write-Host 'A pasta está vazia, nada para mover.'; return }
    if ((Test-Path -LiteralPath $destino) -and (Get-ChildItem -LiteralPath $destino -Force | Select-Object -First 1)) {
        Erro "Já existe $destino com arquivos dentro. Confira essa pasta antes."
        return
    }
    if ($medida.Bytes -gt (Espaco-Livre $Script:Destino) - 1GB) { Erro 'Não tem espaço suficiente no HD.'; return }

    Write-Host ''
    Write-Host "Tamanho: $(Formatar-Tamanho $medida.Bytes) ($($medida.Arquivos) arquivos)"
    Write-Host "De:   $origem"
    Write-Host "Para: $destino"
    Avisar 'Feche o programa/jogo antes (confira também os ícones perto do relógio).'
    if (-not (Confirmar 'Mover?')) { return }

    # 1) Renomeia a original. Se algum arquivo estiver aberto o Windows não deixa,
    #    e paramos aqui sem ter mexido em nada.
    $nomeOriginal = [IO.Path]::GetFileName($origem)
    $temporaria = "$origem.movendo-para-hd"
    if (Test-Path -LiteralPath $temporaria) {
        Erro "Existe $temporaria (de uma tentativa anterior). Renomeie de volta para '$nomeOriginal' e tente de novo."
        return
    }
    try { Rename-Item -LiteralPath $origem -NewName ([IO.Path]::GetFileName($temporaria)) }
    catch { Erro 'A pasta está em uso. Feche o programa e tente de novo.'; return }

    # 2) Copia para o HD e confere se chegou tudo.
    Write-Host 'Copiando para o HD (pode demorar)...'
    New-Item -ItemType Directory -Path $destino -Force | Out-Null
    $codigo = Robocopy-Copiar $temporaria $destino
    $copia = Medir-Pasta $destino
    if ($codigo -ge 8 -or $copia.Arquivos -ne $medida.Arquivos -or $copia.Bytes -ne $medida.Bytes) {
        Erro "A cópia não ficou completa (robocopy: $codigo). Desfazendo..."
        $null = Apagar-Arvore $destino -IncluirPasta
        Rename-Item -LiteralPath $temporaria -NewName $nomeOriginal
        Write-Host 'Tudo voltou como estava.'
        return
    }

    # 3) Cria o link no lugar da pasta original.
    try { New-Item -ItemType Junction -Path $origem -Value $destino | Out-Null }
    catch {
        Erro "Não consegui criar o link ($($_.Exception.Message)). Desfazendo..."
        Rename-Item -LiteralPath $temporaria -NewName $nomeOriginal
        $null = Apagar-Arvore $destino -IncluirPasta
        Write-Host 'Tudo voltou como estava.'
        return
    }

    # 4) Só agora apaga a cópia do SSD.
    $null = Apagar-Arvore $temporaria -IncluirPasta
    if (Test-Path -LiteralPath $temporaria) {
        Avisar "Não consegui apagar tudo de $temporaria. Pode apagar essa pasta manualmente."
    }

    $registro = Join-Path $Script:Destino 'MovidoDoSSD\pastas-movidas.txt'
    Add-Content -LiteralPath $registro -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm')   $origem   ->   $destino"
    Ok "Pronto! $(Formatar-Tamanho $medida.Bytes) liberados no SSD."
    Write-Host 'Abra o programa para conferir. Para desfazer, use a opção 7.'
}

function Trazer-DeVolta {
    Escrever-Titulo 'Trazer de volta para o SSD uma pasta movida na opção 6'
    $registro = Join-Path $Script:Destino 'MovidoDoSSD\pastas-movidas.txt'
    if (Test-Path -LiteralPath $registro) {
        Write-Host 'Pastas movidas até agora:'
        Get-Content -LiteralPath $registro -Encoding UTF8 | ForEach-Object { Write-Host "  $_" }
    }
    $origem = Ler-Caminho "`nCaminho ORIGINAL da pasta, o do $Sistema (Enter para cancelar)"
    if (-not $origem) { return }
    if ($origem.Length -le 3 -or -not (Esta-Dentro $origem $Sistema)) { Erro "Use o caminho do $Sistema."; return }

    $item = Get-Item -LiteralPath $origem -Force -ErrorAction SilentlyContinue
    if (-not $item -or -not $item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        Erro 'Essa pasta não é um link criado pela opção 6.'
        return
    }
    $destino = Caminho-NoHD $origem
    if (-not (Test-Path -LiteralPath $destino -PathType Container)) { Erro "Não achei a pasta no HD: $destino"; return }

    $medida = Medir-Pasta $destino
    if ($medida.Bytes -gt (Espaco-Livre $LetraSistema) - 2GB) { Erro 'Não tem espaço suficiente no SSD.'; return }
    Write-Host "Vai voltar $(Formatar-Tamanho $medida.Bytes) para $origem"
    Avisar 'Feche o programa/jogo antes.'
    if (-not (Confirmar 'Trazer de volta?')) { return }

    # Mesmo cuidado da ida: renomear falha se algo estiver aberto.
    $nomeNoHD = [IO.Path]::GetFileName($destino)
    $temporaria = "$destino.voltando-para-ssd"
    try { Rename-Item -LiteralPath $destino -NewName ([IO.Path]::GetFileName($temporaria)) }
    catch { Erro 'A pasta está em uso. Feche o programa e tente de novo.'; return }

    [IO.Directory]::Delete($origem, $false)   # remove só o link; os arquivos no HD não são tocados
    New-Item -ItemType Directory -Path $origem | Out-Null
    Write-Host 'Copiando de volta (pode demorar)...'
    $codigo = Robocopy-Copiar $temporaria $origem
    $copia = Medir-Pasta $origem
    if ($codigo -ge 8 -or $copia.Arquivos -ne $medida.Arquivos -or $copia.Bytes -ne $medida.Bytes) {
        Erro "A cópia não ficou completa (robocopy: $codigo). Desfazendo..."
        $null = Apagar-Arvore $origem -IncluirPasta
        Rename-Item -LiteralPath $temporaria -NewName $nomeNoHD
        New-Item -ItemType Junction -Path $origem -Value $destino | Out-Null
        Write-Host 'Tudo voltou como estava.'
        return
    }
    $null = Apagar-Arvore $temporaria -IncluirPasta
    Add-Content -LiteralPath $registro -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm')   $origem   <-   voltou para o SSD"
    Ok 'Pronto, a pasta voltou para o SSD.'
}

# ---------------------------------------------------------------------------
# 9) Dicas para instalar coisas novas no HD
# ---------------------------------------------------------------------------
function Mostrar-Dicas {
    Escrever-Titulo 'Programas e jogos novos direto no HD'
    foreach ($pasta in 'Programas', 'Jogos') {
        New-Item -ItemType Directory -Path (Join-Path $Script:Destino $pasta) -Force | Out-Null
    }
    $d = $Script:Destino
    Write-Host @"
Criei as pastas $d\Programas e $d\Jogos para você usar.

 * Programas: na instalação, clique em "Procurar"/"Alterar" e troque
   C:\Program Files\... por $d\Programas\NomeDoPrograma
 * Steam: Configurações > Armazenamento > Adicionar unidade > $d
   e deixe como padrão. Jogo já instalado: selecione ele e use "Mover".
 * Epic Games: na hora de instalar, troque a pasta em "Procurar".
 * Microsoft Store / app Xbox: Configurações do Windows > Sistema > Armazenamento >
   Configurações de armazenamento avançadas > Onde o novo conteúdo é salvo >
   "Novos aplicativos serão salvos em": $d
 * Programa que já está no $Sistema e não tem opção de mudar: opção 6.

Lembre: o HD é mais lento que o SSD. Deixe no SSD só o que você usa
todo dia (por exemplo o jogo que você mais joga).
"@
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Mostrar-Menu {
    Clear-Host
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host '   LIBERAR ESPAÇO NO SSD  -  deixar só o Windows no SSD' -ForegroundColor Cyan
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host ("   SSD ({0})  livre: {1}" -f $Sistema, (Formatar-Tamanho (Espaco-Livre $LetraSistema)))
    Write-Host ("   HD  ({0})  livre: {1}" -f $Script:Destino, (Formatar-Tamanho (Espaco-Livre $Script:Destino)))
    Write-Host ''
    Write-Host '   1) Ver o que está enchendo o SSD'
    Write-Host '   2) Mover Área de Trabalho, Documentos, Downloads, Imagens, Músicas e Vídeos para o HD'
    Write-Host '   3) Mandar os arquivos temporários para o HD'
    Write-Host '   4) Limpeza do SSD (temporários, cache do Windows Update, lixeira...)'
    Write-Host '   5) Desligar a hibernação (libera alguns GB)'
    Write-Host '   6) Mover a pasta de um programa/jogo já instalado para o HD'
    Write-Host '   7) Trazer de volta uma pasta movida na opção 6'
    Write-Host '   8) Fazer o recomendado de uma vez (2 + 3 + 4)'
    Write-Host '   9) Como instalar programas e jogos novos direto no HD'
    Write-Host '   0) Sair'
    Write-Host ''
}

try {
    $logado = (Get-CimInstance Win32_ComputerSystem).UserName
    if ($logado -and $logado -ne "$env:USERDOMAIN\$env:USERNAME") {
        Avisar "Atenção: o Windows está aberto na conta '$logado', mas o script está rodando como '$env:USERDOMAIN\$env:USERNAME'."
        Avisar "As opções 2 e 3 vão mexer nas pastas de '$env:USERNAME'. O ideal é usar uma conta de administrador no dia a dia."
    }
} catch { }

if (-not (Escolher-Destino)) {
    Read-Host 'Pressione Enter para sair' | Out-Null
    exit
}

while ($true) {
    Mostrar-Menu
    $opcao = (Read-Host 'Escolha uma opção').Trim()
    if ($opcao -eq '0') { break }
    try {
        switch ($opcao) {
            '1' { Relatorio }
            '2' { Mover-PastasPessoais }
            '3' { Mover-Temporarios }
            '4' { Limpeza }
            '5' { Desligar-Hibernacao }
            '6' { Mover-PastaComLink }
            '7' { Trazer-DeVolta }
            '8' { Mover-PastasPessoais; Mover-Temporarios; Limpeza; Mostrar-Dicas }
            '9' { Mostrar-Dicas }
            default { Erro 'Opção inválida.' }
        }
    } catch {
        Erro "`nDeu erro: $($_.Exception.Message)"
    }
    Pausar
}
