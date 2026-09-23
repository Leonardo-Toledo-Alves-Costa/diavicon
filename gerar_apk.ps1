# Gera o APK (ou o AAB da Play Store) de publicação, assinado e com o código
# Dart ofuscado.
#
# Uso:
#   .\gerar_apk.ps1            -> APK  (build\app\outputs\flutter-apk\)
#   .\gerar_apk.ps1 -Loja      -> AAB  (build\app\outputs\bundle\release\)
#
# Ofuscação: os nomes de classes e funções viram letras sem sentido, o que
# dificulta copiar a lógica do app. Os "símbolos" (o mapa para decifrar um
# relatório de erro) ficam em simbolos\<versão>\ — guarde essa pasta junto
# com cada versão publicada e NÃO a envie para ninguém.

param([switch]$Loja)

$ErrorActionPreference = "Stop"
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pasta

$versao = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$simbolos = Join-Path $pasta ("simbolos\" + ($versao -replace '\+', '_'))
New-Item -ItemType Directory -Force -Path $simbolos | Out-Null

$alvo = if ($Loja) { "appbundle" } else { "apk" }
Write-Host "Gerando $alvo da versão $versao (ofuscado)..." -ForegroundColor Yellow

# Avisos do Flutter saem na saída de erro; quem decide é o código de saída.
$ErrorActionPreference = "Continue"
flutter build $alvo --release --obfuscate --split-debug-info="$simbolos"
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Host "A geração falhou. Veja a mensagem acima." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Pronto. Símbolos guardados em: $simbolos" -ForegroundColor Green
if ($Loja) {
    Start-Process explorer.exe (Join-Path $pasta "build\app\outputs\bundle\release")
} else {
    Start-Process explorer.exe (Join-Path $pasta "build\app\outputs\flutter-apk")
}
