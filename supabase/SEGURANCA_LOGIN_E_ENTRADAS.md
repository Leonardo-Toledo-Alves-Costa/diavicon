# Segurança do login e das entradas — o que falta no Supabase

O app (celular e web) já tem as proteções do lado do cliente (resumo no fim).
Os itens abaixo são **configurações do Supabase** e ficam com a equipe: nada
disso foi aplicado no projeto de produção.

## Por que o servidor é indispensável

Quem tenta descobrir senhas por força bruta não usa o app: chama direto
`POST /auth/v1/token?grant_type=password` com a chave `anon` (que é pública,
está dentro do app). O limite de tentativas do app ajuda o usuário comum e
atrapalha quem usa a interface, mas **só o servidor barra a API**.

## Passos (em ordem)

### 1. Limites de requisição — Authentication › Rate Limits

| Limite | Recomendado | Observação |
|---|---|---|
| Sign-ups and sign-ins (por IP, 5 min) | 30 | padrão do Supabase; baixar para 20 se não houver muitos usuários atrás do mesmo IP (escritório, obra com roteador único) |
| Token verifications (por IP, 5 min) | 30 | códigos de e-mail/OTP |
| Token refreshes (por IP, 5 min) | 150 | |
| E-mails enviados (por hora) | padrão | só dá para subir com SMTP próprio |

Os mesmos valores estão em `supabase/config.toml` (`[auth.rate_limit]`). O
arquivo vale para o ambiente local; em produção, aplique pelo painel ou com
`supabase config push`, depois de revisar.

### 2. Política de senha — Authentication › Providers › Email

- **Minimum password length:** 8
- **Password requirements:** letras e números (`letters_digits`)
- **Leaked password protection:** ligar (HaveIBeenPwned; exige plano Pro). O
  app já traduz esse erro para o usuário.
- **Secure password change:** ligar (trocar a senha exige login recente).

A validação do app (`ValidatorsCadastro.senha`) já exige o mesmo. Quem tem
senha antiga de 6 caracteres continua entrando; a regra vale para senhas novas.

### 3. CAPTCHA — Authentication › Attack Protection (quando decidirem)

É a proteção mais forte contra robôs. Precisa de duas partes juntas:

1. criar a chave no Cloudflare Turnstile (gratuito) ou hCaptcha;
2. o app enviar o `captchaToken` no login, cadastro e recuperação.

**Não ligue o CAPTCHA antes da parte 2**, senão todo login falha. A parte 2
ainda não está no app. No web é simples (widget JS); no celular exige uma
WebView. Quando tiverem a chave do site, é o próximo passo de código.

### 4. Auditoria do banco (somente leitura)

Rode `supabase/audit_seguranca_entradas.sql` no SQL Editor de produção.
Ele lista:
- funções com SQL dinâmico;
- funções que montam SQL concatenando texto (o único jeito de haver SQL
  injection com Supabase);
- funções `SECURITY DEFINER` sem `search_path` fixo;
- funções expostas à API;
- tabelas sem RLS.

As migrations do repositório passaram nessa checagem. O banco de produção
tem funções anteriores a elas, que só essa consulta alcança.

### 5. Edge Function `convidar-funcionario` (fazer deploy)

A senha provisória do convite passou de 8 caracteres aleatórios mais o sufixo
fixo `@1A` para 16 caracteres aleatórios com todas as classes. O código novo
está em `supabase/functions/convidar-funcionario/index.ts`; falta o deploy:

```
supabase functions deploy convidar-funcionario
```

## O que já está no app (celular e web)

- **Login:**
  - 3 erros livres por e-mail, depois espera de 30 s → 1 min → 2 min → 5 min → 15 min;
  - mais de 10 erros em 15 min no mesmo aparelho, com qualquer e-mail, pausam o login por 5 min;
  - o estado sobrevive a fechar o app ou recarregar a página;
  - só erro de senha conta; queda de rede não conta;
  - mensagem única "E-mail ou senha incorretos", para não revelar quais e-mails existem;
  - o erro 429 do servidor vira "aguarde alguns minutos".
- **Recuperação de senha:**
  - 1 min entre envios; a partir do 3º, 15 min;
  - botão travado durante o envio;
  - mesma resposta exista ou não a conta.
- **Campos:**
  - todos os `CustomTextField` bloqueiam caracteres de controle invisíveis e têm limite de tamanho;
  - e-mail até 254 caracteres e senha até 72 (limite do bcrypt).
- **Consultas:**
  - o app não monta SQL; o PostgREST envia tudo como parâmetro;
  - as buscas digitadas que entravam em filtros de texto (`.or()`/`ilike`) agora são escapadas (`EntradaSegura`).
- **Relatórios (HTML → PDF):**
  - todo texto é escapado, inclusive aspas;
  - imagens e links só aceitam `http(s)` e imagens em base64.
