# Cria a chave de assinatura do aplicativo Android.
#
# Rodar UMA vez, no PowerShell, dentro da pasta android:
#   .\criar_chave.ps1
#
# O script acha o keytool sozinho, pergunta a senha, gera o arquivo .jks em
# %USERPROFILE%\chaves e já escreve o key.properties apontando para ele.
#
# A senha NÃO aparece na tela nem fica no histórico do PowerShell — ela é lida
# como texto oculto e vai direto para o keytool.
#
# Nada aqui tem a ver com "chave de segurança USB" nem com iPhone: isso é
# outra coisa (verificação em duas etapas de conta Apple/Google). Esta chave é
# só um arquivo no seu computador.

$ErrorActionPreference = 'Stop'
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '=== DIAVICON - chave de assinatura do Android ===' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------------------
# 1. Achar o keytool (vem junto com o Java do Android Studio).
# ---------------------------------------------------------------------------
$candidatos = @()
$doPath = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if ($doPath) { $candidatos += $doPath }
if ($env:JAVA_HOME) { $candidatos += (Join-Path $env:JAVA_HOME 'bin\keytool.exe') }
# No PowerShell de 32 bits (x86), $env:ProgramFiles aponta para
# "C:\Program Files (x86)" - e o Android Studio fica em "C:\Program Files".
# O ProgramW6432 aponta para a pasta de 64 bits nos dois casos.
$candidatos += "$env:ProgramW6432\Android\Android Studio\jbr\bin\keytool.exe"
$candidatos += "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
$candidatos += "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$candidatos += "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe"
$candidatos += "${env:ProgramFiles(x86)}\Android\Android Studio\jbr\bin\keytool.exe"
# Ultimo recurso: qualquer Android Studio / Java instalado nas pastas de
# programas (versoes antigas usavam "jre" em vez de "jbr").
foreach ($raiz in @("$env:ProgramW6432", 'C:\Program Files', "$env:LOCALAPPDATA\Programs")) {
    if ($raiz -and (Test-Path $raiz)) {
        $candidatos += Get-ChildItem -Path $raiz -Filter keytool.exe -Recurse -Depth 5 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName
    }
}

$keytool = $null
foreach ($c in $candidatos) {
    if ($c -and (Test-Path $c)) { $keytool = (Get-Item $c).FullName; break }
}

if (-not $keytool) {
    Write-Host 'Nao encontrei o keytool.' -ForegroundColor Red
    Write-Host 'Ele vem junto com o Android Studio. Instale o Android Studio e rode de novo,'
    Write-Host 'ou defina a variavel JAVA_HOME apontando para uma instalacao do Java.'
    exit 1
}
Write-Host "keytool: $keytool" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 2. Onde o arquivo vai ficar.
# ---------------------------------------------------------------------------
$destinoPasta = Join-Path $env:USERPROFILE 'chaves'
$destino = Join-Path $destinoPasta 'diavicon-publicacao.jks'
$apelido = 'diavicon'

if (Test-Path $destino) {
    Write-Host ''
    Write-Host "Ja existe uma chave em: $destino" -ForegroundColor Yellow
    Write-Host 'NAO gere outra por cima: a Play Store so aceita atualizacoes assinadas'
    Write-Host 'com a mesma chave da primeira versao publicada.'
    Write-Host 'Se precisar recomecar do zero, mova o arquivo antigo para outro lugar antes.'
    exit 1
}
New-Item -ItemType Directory -Force $destinoPasta | Out-Null

# ---------------------------------------------------------------------------
# 3. Senha (digitada por voce, oculta).
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Escolha uma senha para a chave (minimo 6 caracteres).' -ForegroundColor Yellow
Write-Host 'GUARDE ESSA SENHA. Sem ela, nunca mais sera possivel publicar uma'
Write-Host 'atualizacao deste aplicativo - nao existe recuperacao.'
Write-Host ''

$senha1 = Read-Host 'Senha' -AsSecureString
$senha2 = Read-Host 'Repita a senha' -AsSecureString

$texto1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha1))
$texto2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($senha2))

if ($texto1 -ne $texto2) {
    Write-Host 'As senhas nao sao iguais. Rode de novo.' -ForegroundColor Red
    exit 1
}
if ($texto1.Length -lt 6) {
    Write-Host 'A senha precisa ter pelo menos 6 caracteres.' -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# 4. Gerar. O -dname evita as seis perguntas do keytool.
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Gerando a chave...' -ForegroundColor Yellow

$identificacao = 'CN=Diavicon, OU=Tecnologia, O=Diavicon, L=Sao Paulo, ST=SP, C=BR'

& $keytool -genkeypair -v `
    -keystore $destino `
    -storetype JKS `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -alias $apelido `
    -dname $identificacao `
    -storepass $texto1 -keypass $texto1

if ($LASTEXITCODE -ne 0) {
    Write-Host 'O keytool falhou. Veja a mensagem acima.' -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# 5. Escrever o key.properties.
# ---------------------------------------------------------------------------
$arquivoProps = Join-Path $pasta 'key.properties'
$caminhoParaOGradle = $destino.Replace('\', '/')

@"
# Gerado por criar_chave.ps1. NAO versionar este arquivo.
keyAlias=$apelido
keyPassword=$texto1
storePassword=$texto1
storeFile=$caminhoParaOGradle
"@ | Out-File -FilePath $arquivoProps -Encoding utf8 -NoNewline

# A senha sai da memoria do script.
$texto1 = $null; $texto2 = $null
[GC]::Collect()

Write-Host ''
Write-Host 'Pronto.' -ForegroundColor Green
Write-Host ''
Write-Host "  Chave:          $destino"
Write-Host "  Configuracao:   $arquivoProps"
Write-Host ''
Write-Host 'FACA COPIA DA CHAVE AGORA, em pelo menos dois lugares (nuvem pessoal,'
Write-Host 'cofre de senhas da empresa). Guarde a senha junto.' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Para gerar o pacote da Play Store:'
Write-Host '   flutter build appbundle --release'
Write-Host ''

# ---------------------------------------------------------------------------
# 6. Impressoes digitais (precisam ir para o Firebase, senao o login com
#    Google para de funcionar na versao assinada).
# ---------------------------------------------------------------------------
Write-Host 'Impressoes digitais desta chave (guarde para o Firebase):' -ForegroundColor Cyan
$props = Get-Content $arquivoProps | Where-Object { $_ -like 'storePassword=*' }
$senhaLida = $props -replace '^storePassword=', ''
& $keytool -list -v -keystore $destino -alias $apelido -storepass $senhaLida |
    Select-String -Pattern 'SHA1:|SHA256:'
