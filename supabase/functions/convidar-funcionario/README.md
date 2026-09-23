# convidar-funcionario

Cria o acesso de um funcionário da empresa, devolve a senha provisória para a
tela **e** manda essa senha por e-mail para a pessoa convidada.

O e-mail é o último passo de propósito: se o envio falhar, o convite continua
valendo e a tela mostra a senha junto com o motivo da falha, para o
administrador passar por outro caminho.

## Como o e-mail sai

Três caminhos, nesta ordem:

1. **Brevo** (recomendado), se existir o segredo `BREVO_API_KEY`. É uma
   chamada HTTP comum — sem porta, sem TLS para negociar.
2. **Resend**, se existir `RESEND_API_KEY`. Mesma ideia.
3. **SMTP**, se existir `SMTP_SENHA`.

O SMTP dentro das Edge Functions depende de abrir conexão crua com o servidor
de e-mail, e a porta **587 (STARTTLS) derruba a função** neste ambiente —
sobra só a 465. Por isso o Resend é o caminho preferido.

## Configuração pelo Brevo (recomendado)

1. No Brevo, **SMTP & API › API Keys › Generate a new API key**.
2. Valide o remetente em **Senders, Domains & Dedicated IPs** — o endereço
   `contato@diavicon.com.br` precisa aparecer como validado ali, senão o
   Brevo recusa o envio com 400.
3. No painel do Supabase, **Edge Functions › Secrets**:

| Segredo | Valor |
| --- | --- |
| `BREVO_API_KEY` | a chave gerada |
| `EMAIL_DE` | `no-reply <contato@diavicon.com.br>` (opcional; o padrão já usa esse endereço) |

### Brevo por SMTP, se preferir

O relay do Brevo também funciona, desde que na **porta 465** — a 587 derruba
a função neste ambiente. A senha é a **chave SMTP** do Brevo (SMTP & API ›
SMTP), não a senha da conta.

| Segredo | Valor |
| --- | --- |
| `SMTP_HOST` | `smtp-relay.brevo.com` |
| `SMTP_PORTA` | `465` |
| `SMTP_USUARIO` | o login que o Brevo mostra (termina em `@smtp-brevo.com`) |
| `SMTP_SENHA` | a chave SMTP do Brevo |

Se `BREVO_API_KEY` estiver cadastrado, ele tem prioridade sobre o SMTP.

## Configuração pelo Resend (alternativa)

1. Crie a conta em https://resend.com (3.000 e-mails/mês no plano gratuito).
2. Em **API Keys**, gere uma chave (começa com `re_`).
3. No painel do Supabase, **Edge Functions › Secrets**:

| Segredo | Valor |
| --- | --- |
| `RESEND_API_KEY` | a chave gerada |

Já funciona: enquanto o domínio não estiver verificado, o remetente é o
endereço de teste do Resend (`onboarding@resend.dev`), que é o padrão.

4. Depois, em **Domains**, verifique `diavicon.com.br` (o Resend mostra os
   registros de DNS para cadastrar no painel do domínio) e troque o segredo:

| Segredo | Valor |
| --- | --- |
| `RESEND_DE` | `Diavicon <naoresponda@diavicon.com.br>` |

Sem essa verificação o Resend recusa o remetente com 422.

## Configuração pelo SMTP (alternativa)

Só o `SMTP_SENHA` é obrigatório; o resto tem padrão.

| Segredo | Padrão | Para que serve |
| --- | --- | --- |
| `SMTP_SENHA` | — | Senha da caixa de e-mail |
| `SMTP_HOST` | `smtp.titan.email` | Servidor de saída |
| `SMTP_PORTA` | `465` | **Use 465.** A 587 derruba a função neste ambiente |
| `SMTP_USUARIO` | `naoresponda@diavicon.com.br` | Caixa que envia (e remetente) |
| `SMTP_REMETENTE` | `Diavicon` | Nome que aparece no "de:" |

A caixa `naoresponda@diavicon.com.br` fica no **Titan** (serviço revendido
pela HostGator), e não no servidor do domínio: autenticar em
`mail.diavicon.com.br` com uma caixa do Titan devolve **535**. Confirme a
senha entrando em https://app.titan.email antes de cadastrar o segredo.

## Outros segredos

| Segredo | Padrão | Para que serve |
| --- | --- | --- |
| `APP_URL` | `https://diavicon.com.br/app` | Endereço do app, usado no botão do e-mail |

## Publicar

A função é um arquivo só (`index.ts`), então dá para publicar pelo painel:
**Edge Functions › convidar-funcionario**, cole o conteúdo no editor e clique
em Deploy. Pelo terminal:

```bash
supabase functions deploy convidar-funcionario
```

Trocar um segredo não exige publicar de novo.

## Se o e-mail não chegar

A própria tela do convite mostra o motivo devolvido pela função. Os mais
comuns:

- **"cadastre BREVO_API_KEY, RESEND_API_KEY ou SMTP_SENHA"** — nenhum deles
  foi cadastrado.
- **"O Brevo recusou a chave"** — `BREVO_API_KEY` errada ou revogada.
- **"O Brevo recusou o remetente"** — o endereço de `EMAIL_DE` não está
  validado em Senders & Domains.
- **"O Resend recusou a chave"** — `RESEND_API_KEY` errada ou revogada.
- **"O Resend recusou o remetente"** — `RESEND_DE` usa um domínio ainda não
  verificado no Resend.
- **535 / recusou o usuário e a senha** — credencial do SMTP. O usuário é o
  endereço completo, com `@`, e o servidor precisa ser o do provedor da caixa.
- **`service_unavailable`** — quase sempre `SMTP_PORTA=587`. Volte para 465.
- **chegou na caixa de spam** — verifique o domínio no Resend (ou configure
  SPF e DKIM, no caso do SMTP).
