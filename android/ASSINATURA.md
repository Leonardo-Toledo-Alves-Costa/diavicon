# Assinatura do aplicativo Android

Todo APK precisa ser assinado. Hoje, sem configuração, o Flutter assina com uma
chave de **depuração**: o app instala à mão, mas a Play Store recusa.

Para publicar na loja é preciso uma chave sua. Ela é o documento de identidade
do aplicativo: o Android só aceita uma atualização assinada com a **mesma**
chave da versão anterior.

## Guarde bem a chave

> **Se você perder o arquivo `.jks` ou a senha, não existe recuperação.**
> Você não conseguirá mais publicar atualizações deste aplicativo — seria
> preciso criar outro, com outro nome de pacote, e pedir para todo mundo
> reinstalar.

Recomendações:

- Guarde o `.jks` **fora da pasta do projeto** (ex.: `C:\Users\popch\chaves\`).
- Faça pelo menos duas cópias em lugares diferentes (um pendrive e um cofre de
  senhas, por exemplo). Não confie só no OneDrive.
- Guarde a senha no mesmo gerenciador de senhas da empresa, anotando o apelido
  (`keyAlias`) junto.
- Nunca envie o `.jks` nem o `key.properties` para o repositório. O
  `android/.gitignore` já bloqueia os dois, mas vale conferir.

## 1. Criar a chave — jeito fácil

Abra o **PowerShell**, entre na pasta `android` do projeto e rode:

```powershell
.\criar_chave.ps1
```

O script acha o `keytool` sozinho, pergunta a senha (digitada oculta, duas
vezes), gera o `.jks` em `%USERPROFILE%\chaves`, já escreve o `key.properties`
apontando para ele e mostra as impressões digitais SHA-1/SHA-256 no fim.

Se o PowerShell recusar por política de execução, rode antes:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Isso vale só para essa janela do PowerShell e volta ao normal quando você a
fecha.

> Esta chave **não** é "chave de segurança USB" nem tem relação com iPhone ou
> iPad. Isso é outra coisa: verificação em duas etapas de conta Apple/Google.
> Aqui é só um arquivo gerado no seu computador.

## 1b. Criar a chave — na mão

Se preferir fazer sem o script, o comando é este. Ele vai perguntar uma senha (e
repetir), depois alguns dados da empresa — nome, unidade, cidade, estado e o
código do país (**BR**). Pode responder o que fizer sentido; nada disso aparece
para o usuário final.

Neste computador o `keytool` está no Java que vem com o Android Studio:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\chaves" | Out-Null
& "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\chaves\diavicon-publicacao.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias diavicon
```

O `-validity 10000` são cerca de 27 anos. A Play Store exige uma chave que
valha até pelo menos 2033.

## 2. Apontar o projeto para a chave

Copie `key.properties.exemplo` para `key.properties`, na mesma pasta
(`android/`), e preencha com os seus valores:

```properties
keyAlias=diavicon
keyPassword=a-senha-que-você-escolheu
storePassword=a-senha-que-você-escolheu
storeFile=C:/Users/popch/chaves/diavicon-publicacao.jks
```

Detalhes que costumam dar trabalho:

- o caminho usa **barras normais** (`/`), mesmo no Windows;
- se a senha tiver `\`, escreva `\\`;
- o `keyAlias` precisa ser exatamente o que veio depois de `-alias` no comando.

Pronto: o `build.gradle.kts` lê esse arquivo sozinho. Sem ele, o build volta a
usar a chave de depuração — nada quebra para quem só roda o app.

## 3. Gerar o pacote

Para a Play Store, o formato é o **AAB** (não o APK):

```powershell
flutter build appbundle --release
```

Sai em `build\app\outputs\bundle\release\app-release.aab`.

Para instalar à mão (fora da loja), o APK continua valendo:

```powershell
flutter build apk --release
```

## 4. Conferir que assinou certo

```powershell
& "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\chaves\diavicon-publicacao.jks" -alias diavicon
```

Anote a impressão digital **SHA-1** e a **SHA-256** que aparecem. Elas são
necessárias para:

- o **login com Google** (Firebase › Configurações do projeto › adicionar
  impressão digital); sem isso o botão do Google para de funcionar na versão
  da loja;
- os **links do app** (`diavicon://`), se um dia virarem links `https://`.

> Atenção: com a Play Store ativando a *assinatura de apps do Google Play*, a
> loja re-assina o pacote com uma chave própria. A SHA-1 que vale para o
> Firebase, nesse caso, é a que aparece no **Play Console › Configuração ›
> Integridade do app**, e não só a do seu `.jks`. Cadastre as duas.

## 5. Quando trocar de computador

Leve o `.jks` e recrie o `key.properties` no novo computador. O arquivo de
chave não é gerado de novo — é sempre o mesmo, pela vida inteira do aplicativo.
