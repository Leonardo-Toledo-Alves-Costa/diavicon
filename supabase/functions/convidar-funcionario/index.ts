import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Senha provisória do convite: 16 caracteres aleatórios (~90 bits), com
// letra minúscula, maiúscula, número e símbolo garantidos. A versão anterior
// tinha 8 aleatórios + o sufixo fixo "@1A" (~47 bits, e o sufixo era
// conhecido), o que encurtava um ataque de força bruta.
/** Inteiro aleatório uniforme em [0, n) — amostragem por rejeição, sem viés. */
function inteiroAleatorio(n: number): number {
  const limite = Math.floor(0x100000000 / n) * n
  const b = new Uint32Array(1)
  for (;;) {
    crypto.getRandomValues(b)
    if (b[0] < limite) return b[0] % n
  }
}

const sortear = (alfabeto: string) => alfabeto.charAt(inteiroAleatorio(alfabeto.length))

function gerarSenhaProvisoria() {
  // Sem caracteres ambíguos (l, I, O, 0, 1) — a senha é lida e digitada.
  const minusculas = 'abcdefghijkmnopqrstuvwxyz'
  const maiusculas = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
  const numeros = '23456789'
  const simbolos = '@#$%&*+-=?!'
  const todos = minusculas + maiusculas + numeros + simbolos
  const chars = [sortear(minusculas), sortear(maiusculas), sortear(numeros), sortear(simbolos)]
  while (chars.length < 16) chars.push(sortear(todos))
  // Embaralha (Fisher–Yates) para as classes garantidas não ficarem no início.
  for (let i = chars.length - 1; i > 0; i--) {
    const j = inteiroAleatorio(i + 1)
    ;[chars[i], chars[j]] = [chars[j], chars[i]]
  }
  return chars.join('')
}

function response(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    status,
  })
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (isRecord(error) && typeof error.message === 'string' && error.message.trim()) return error.message
  return 'Erro interno.'
}

function errorCode(error: unknown): string | null {
  return isRecord(error) && typeof error.code === 'string' ? error.code : null
}

// Validação de entrada: formato do e-mail, tamanhos e caracteres de controle
// (uma quebra de linha no e-mail poderia injetar cabeçalhos no envio SMTP).
const FORMATO_EMAIL = /^[^\s@<>()\[\],;:"]+@[^\s@<>()\[\],;:"]+\.[a-zA-Z]{2,}$/
const TEM_CONTROLE = /[\u0000-\u001f\u007f]/

function textoLimitado(value: unknown, max: number): string | null {
  const t = text(value)
  if (!t || t.length > max || TEM_CONTROLE.test(t)) return null
  return t
}

// Convites por empresa em 24 h. Conta pela auditoria (não some quando o
// convite é desfeito). Sem a função no banco, não limita.
const LIMITE_CONVITES_DIA = 20

// Envio do e-mail com a senha provisória do convite.
//
// A caixa naoresponda@diavicon.com.br fica no Titan, o serviço de e-mail que
// a HostGator revende — por isso o servidor é o do Titan, e não
// `mail.diavicon.com.br`. Tentar autenticar no servidor do domínio com uma
// caixa do Titan devolve 535 (usuário ou senha recusados).
//
// Nada aqui fica no código: a senha da caixa vem dos segredos da função,
// cadastrados no painel (Edge Functions › Secrets) ou por
//
//   supabase secrets set SMTP_SENHA=...
//
// Valores padrão (todos podem ser trocados por segredo):
//   SMTP_HOST      smtp.titan.email
//   SMTP_PORTA     465            (SSL; use 587 para STARTTLS)
//   SMTP_USUARIO   naoresponda@diavicon.com.br
//   SMTP_REMETENTE Diavicon
//   APP_URL        https://diavicon.com.br/app
//
// Para sair por outro provedor (Gmail, por exemplo) basta cadastrar
// SMTP_HOST, SMTP_PORTA e SMTP_USUARIO — o código não muda.
//
// O envio nunca derruba o convite: quem chama trata a falha e mostra a senha
// na tela do mesmo jeito.

const PADROES = {
  host: 'smtp.titan.email',
  porta: 465,
  usuario: 'naoresponda@diavicon.com.br',
  remetente: 'Diavicon',
  appUrl: 'https://diavicon.com.br/app',
}

/// Remetente padrão. Trocável pelo segredo `EMAIL_DE`, no formato
/// `Nome <endereco@dominio>`. Precisa ser um remetente validado no provedor.
const REMETENTE_PADRAO = 'Diavicon <contato@diavicon.com.br>'

/// Separa `Nome <endereco>` em nome e endereço. Sem os sinais de maior/menor,
/// o texto inteiro vale como endereço.
function separarRemetente(bruto: string): { nome: string; email: string } {
  const partes = bruto.match(/^\s*(.*?)\s*<\s*([^>]+?)\s*>\s*$/)
  if (partes) return { nome: partes[1] || 'Diavicon', email: partes[2] }
  return { nome: 'Diavicon', email: bruto.trim() }
}

/// Um SMTP que não responde não pode segurar a resposta do convite.
const LIMITE_MS = 20000

function env(nome: string): string | null {
  const valor = Deno.env.get(nome)
  return valor && valor.trim() ? valor.trim() : null
}

function escaparHtml(texto: string): string {
  return texto
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function corpoHtml(nome: string, email: string, senha: string, appUrl: string): string {
  const n = escaparHtml(nome)
  const e = escaparHtml(email)
  const s = escaparHtml(senha)
  const url = escaparHtml(appUrl)
  return `
<table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background:#F6F5F2;padding:32px 12px;font-family:Arial,Helvetica,sans-serif;">
  <tr>
    <td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="max-width:480px;background:#ffffff;border-radius:16px;border-top:6px solid #F9A232;">
        <tr>
          <td style="padding:28px 28px 8px;text-align:center;">
            <div style="font-size:26px;font-weight:bold;letter-spacing:3px;color:#626365;">DIAVICON</div>
            <div style="font-size:12px;color:#6B6D70;margin-top:4px;">Soluções para o diagnóstico da vida útil das construções</div>
          </td>
        </tr>
        <tr>
          <td style="padding:16px 28px 0;color:#2E3033;">
            <h1 style="font-size:22px;margin:0 0 12px;">Olá, ${n}!</h1>
            <p style="font-size:15px;line-height:1.5;color:#4A4A4A;margin:0 0 16px;">
              Criamos o seu acesso à Diavicon. Entre com o e-mail <strong>${e}</strong>
              e a senha provisória abaixo:
            </p>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:0 28px;">
            <div style="display:inline-block;background:#F6F5F2;border:1px solid #E2E0DC;border-radius:12px;padding:16px 24px;font-size:22px;font-weight:bold;letter-spacing:3px;color:#2E3033;">${s}</div>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:20px 28px 8px;">
            <a href="${url}"
               style="display:inline-block;background:#F9A232;color:#2E3033;font-size:16px;font-weight:bold;text-decoration:none;padding:14px 28px;border-radius:12px;">
              Entrar na Diavicon
            </a>
          </td>
        </tr>
        <tr>
          <td style="padding:16px 28px 28px;">
            <p style="font-size:13px;line-height:1.5;color:#6B6D70;margin:0 0 10px;">
              Por segurança, troque essa senha assim que entrar pela primeira vez.
            </p>
            <p style="font-size:12px;line-height:1.5;color:#6B6D70;margin:0;">
              Se o botão não funcionar, copie e cole este endereço no navegador:<br>
              <span style="word-break:break-all;color:#A85A00;">${url}</span>
            </p>
            <p style="font-size:12px;line-height:1.5;color:#6B6D70;margin:14px 0 0;">
              Não esperava este convite? Ignore este e-mail e avise quem administra a sua empresa.
            </p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>`
}

function corpoTexto(nome: string, email: string, senha: string, appUrl: string): string {
  return [
    `Olá, ${nome}!`,
    '',
    'Criamos o seu acesso à Diavicon.',
    `E-mail: ${email}`,
    `Senha provisória: ${senha}`,
    '',
    `Entre em: ${appUrl}`,
    '',
    'Por segurança, troque essa senha assim que entrar pela primeira vez.',
  ].join('\n')
}

/// Traduz o que o servidor de e-mail respondeu.
///
/// Os códigos SMTP não dizem nada a quem está configurando; aqui vira o que
/// fazer. O endereço e a porta entram na mensagem porque o erro quase sempre
/// é um deles estar diferente do que a hospedagem pede.
function explicarFalhaSmtp(motivo: string, host: string, porta: number, usuario: string): string {
  const texto = motivo.toLowerCase()
  const onde = `(servidor ${host}, porta ${porta}, usuário ${usuario})`

  if (texto.includes('535') || texto.includes('authentication') || texto.includes('auth')) {
    // A resposta crua vai junto: o texto que vem depois do 535 é o que
    // distingue senha errada de caixa que não autentica (alias, apelido) ou
    // de bloqueio por origem da conexão.
    return 'O servidor de e-mail recusou o usuário e a senha ' + onde + '. ' +
      'Confira se a caixa existe como caixa de verdade (apelido/alias não autentica) e se a ' +
      'senha do segredo SMTP_SENHA é exatamente a dela. Resposta do servidor: ' + motivo
  }
  if (texto.includes('550') || texto.includes('553') || texto.includes('relay')) {
    return 'O servidor aceitou o login mas recusou o envio ' + onde + '. ' +
      'Normalmente o remetente precisa ser a própria caixa autenticada.'
  }
  if (texto.includes('não respondeu a tempo') || texto.includes('timed out') || texto.includes('timeout')) {
    return 'O servidor de e-mail não respondeu ' + onde + '. ' +
      'Confira o endereço em SMTP_HOST e tente SMTP_PORTA=587.'
  }
  if (texto.includes('connection') || texto.includes('refused') || texto.includes('dns')) {
    return 'Não foi possível chegar ao servidor de e-mail ' + onde + '. ' +
      'Confira o endereço em SMTP_HOST.'
  }
  return 'Não foi possível enviar o e-mail ' + onde + ': ' + motivo
}

type ResultadoEmail = { enviado: true } | { enviado: false; erro: string }

/// Envio pelo Brevo: um POST comum, sem porta, sem TLS para negociar.
///
/// O remetente precisa estar validado no Brevo (Senders, Domains & Dedicated
/// IPs). Enquanto não estiver, o Brevo recusa com 400.
async function enviarPeloBrevo(
  chave: string,
  email: string,
  nome: string,
  senha: string,
): Promise<ResultadoEmail> {
  const de = separarRemetente(env('EMAIL_DE') ?? REMETENTE_PADRAO)
  const appUrl = env('APP_URL') ?? PADROES.appUrl

  try {
    const resposta = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': chave,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        sender: { name: de.nome, email: de.email },
        to: [{ email, name: nome }],
        subject: 'Seu acesso à Diavicon',
        textContent: corpoTexto(nome, email, senha, appUrl),
        htmlContent: corpoHtml(nome, email, senha, appUrl),
      }),
    })

    if (resposta.ok) return { enviado: true }

    const detalhe = await resposta.text()
    if (resposta.status === 401) {
      return { enviado: false, erro: `O Brevo recusou a chave (BREVO_API_KEY). Resposta: ${detalhe}` }
    }
    if (resposta.status === 400 && detalhe.toLowerCase().includes('sender')) {
      return {
        enviado: false,
        erro: `O Brevo recusou o remetente ${de.email}. Valide esse endereço no Brevo ` +
          `(Senders & Domains) ou troque o segredo EMAIL_DE. Resposta: ${detalhe}`,
      }
    }
    return { enviado: false, erro: `O Brevo respondeu ${resposta.status}: ${detalhe}` }
  } catch (erro) {
    const motivo = erro instanceof Error ? erro.message : String(erro)
    return { enviado: false, erro: `Não foi possível falar com o Brevo: ${motivo}` }
  }
}

/// Envio pelo Resend: um POST comum, sem porta, sem TLS para negociar.
///
/// `RESEND_DE` é o remetente. Enquanto o domínio não estiver verificado no
/// Resend, só o endereço de teste deles funciona — que é o padrão abaixo.
/// Depois de verificar diavicon.com.br lá, troque o segredo para
/// `Diavicon <naoresponda@diavicon.com.br>`.
async function enviarPeloResend(
  chave: string,
  email: string,
  nome: string,
  senha: string,
): Promise<ResultadoEmail> {
  const de = env('RESEND_DE') ?? env('EMAIL_DE') ?? 'Diavicon <onboarding@resend.dev>'
  const appUrl = env('APP_URL') ?? PADROES.appUrl

  try {
    const resposta = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${chave}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: de,
        to: [email],
        subject: 'Seu acesso à Diavicon',
        text: corpoTexto(nome, email, senha, appUrl),
        html: corpoHtml(nome, email, senha, appUrl),
      }),
    })

    if (resposta.ok) return { enviado: true }

    const detalhe = await resposta.text()
    if (resposta.status === 401 || resposta.status === 403) {
      return { enviado: false, erro: `O Resend recusou a chave (RESEND_API_KEY). Detalhe: ${detalhe}` }
    }
    if (resposta.status === 422) {
      return {
        enviado: false,
        erro: 'O Resend recusou o remetente. Enquanto o domínio não estiver verificado lá, ' +
          `RESEND_DE precisa ser "Diavicon <onboarding@resend.dev>". Detalhe: ${detalhe}`,
      }
    }
    return { enviado: false, erro: `O Resend respondeu ${resposta.status}: ${detalhe}` }
  } catch (erro) {
    const motivo = erro instanceof Error ? erro.message : String(erro)
    return { enviado: false, erro: `Não foi possível falar com o Resend: ${motivo}` }
  }
}

/// Manda a senha provisória para quem foi convidado.
///
/// Três caminhos, nesta ordem: `BREVO_API_KEY`, `RESEND_API_KEY` e, por
/// último, SMTP. Os dois primeiros são chamadas HTTP comuns e por isso são os
/// preferidos — SMTP dentro das Edge Functions depende de abrir conexão crua,
/// e a porta 587 (STARTTLS) derruba a função neste ambiente, o que deixa só a
/// 465.
async function enviarSenhaProvisoria(
  email: string,
  nome: string,
  senha: string,
): Promise<ResultadoEmail> {
  const chaveBrevo = env('BREVO_API_KEY')
  if (chaveBrevo) return await enviarPeloBrevo(chaveBrevo, email, nome, senha)

  const chaveResend = env('RESEND_API_KEY')
  if (chaveResend) return await enviarPeloResend(chaveResend, email, nome, senha)

  const senhaCaixa = env('SMTP_SENHA')
  if (!senhaCaixa) {
    return {
      enviado: false,
      erro: 'O envio de e-mail ainda não foi configurado: cadastre BREVO_API_KEY (recomendado), '
        + 'RESEND_API_KEY ou SMTP_SENHA.',
    }
  }

  const host = env('SMTP_HOST') ?? PADROES.host
  const portaLida = Number(env('SMTP_PORTA'))
  const porta = Number.isFinite(portaLida) && portaLida > 0 ? portaLida : PADROES.porta
  const usuario = env('SMTP_USUARIO') ?? PADROES.usuario
  const remetente = env('SMTP_REMETENTE') ?? PADROES.remetente
  const appUrl = env('APP_URL') ?? PADROES.appUrl

  // Tudo daqui pra baixo fica dentro do try, inclusive abrir a conexão: se
  // montar o cliente falhar (porta fechada, endereço inválido), quem chamou
  // recebe a falha como resultado e não como exceção.
  let cliente: SMTPClient | null = null
  let relogio = 0
  try {
    cliente = new SMTPClient({
      connection: {
        hostname: host,
        port: porta,
        // 465 abre a conexão já cifrada; 587 começa aberta e sobe para TLS.
        tls: porta === 465,
        auth: { username: usuario, password: senhaCaixa },
      },
    })

    await Promise.race([
      cliente.send({
        from: `${remetente} <${usuario}>`,
        to: email,
        subject: 'Seu acesso à Diavicon',
        content: corpoTexto(nome, email, senha, appUrl),
        html: corpoHtml(nome, email, senha, appUrl),
      }),
      new Promise((_, rejeitar) => {
        relogio = setTimeout(
          () => rejeitar(new Error('o servidor de e-mail não respondeu a tempo')),
          LIMITE_MS,
        )
      }),
    ])
    return { enviado: true }
  } catch (erro) {
    const motivo = erro instanceof Error ? erro.message : String(erro)
    return { enviado: false, erro: explicarFalhaSmtp(motivo, host, porta, usuario) }
  } finally {
    clearTimeout(relogio)
    try {
      await cliente?.close()
    } catch (_) {
      // Conexão já caiu: não há o que fechar.
    }
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return response(405, { erro: 'Método não permitido.' })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const authorization = req.headers.get('Authorization')
    if (!authorization?.startsWith('Bearer ')) return response(401, { erro: 'Autenticação obrigatória.' })

    const supabaseUser = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } },
    )
    const { data: userData, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !userData.user) return response(401, { erro: 'Sessão inválida.' })

    const body = await req.json()
    if (!isRecord(body)) return response(400, { erro: 'Dados do convite inválidos.' })

    const emailBruto = textoLimitado(body.email, 254)
    const email = emailBruto?.toLowerCase() ?? null
    const nome = textoLimitado(body.nome, 60)
    const sobrenome = textoLimitado(body.sobrenome, 80)
    const cargo = textoLimitado(body.cargo, 80)
    const legacyCompanyId = textoLimitado(body.empresa_id, 64)
    const projetoId = textoLimitado(body.projeto_id, 64)
    if (!email || !FORMATO_EMAIL.test(email)) return response(400, { erro: 'E-mail inválido.' })
    if (!nome || !sobrenome || !cargo || !legacyCompanyId) {
      return response(400, { erro: 'Dados do convite inválidos (nome, sobrenome e cargo são obrigatórios, até 60–80 caracteres).' })
    }
    if (body.projeto_id != null && !projetoId) return response(400, { erro: 'Dados do convite inválidos.' })

    const supabaseAdmin = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { data: inviter, error: inviterError } = await supabaseAdmin
      .from('usuarios')
      .select('empresa_id, is_admin_empresa, is_admin, ativo')
      .eq('id', userData.user.id)
      .maybeSingle()

    if (
      inviterError ||
      !inviter ||
      inviter.empresa_id == null ||
      inviter.empresa_id !== legacyCompanyId ||
      inviter.ativo !== true ||
      (inviter.is_admin_empresa !== true && inviter.is_admin !== true)
    ) {
      return response(403, { erro: 'Apenas um administrador ativo da empresa pode convidar funcionários.' })
    }

    const empresaId = inviter.empresa_id as string
    if (projetoId) {
      // Preserve the existing project validation/insertion contract.  This is
      // intentionally read-only and does not modify project RLS or schema.
      const { data: projeto, error: projetoError } = await supabaseAdmin
        .from('projetos')
        .select('id')
        .eq('id', projetoId)
        .eq('empresa_gestora_id', empresaId)
        .maybeSingle()
      if (projetoError || !projeto) return response(403, { erro: 'Projeto inválido para a empresa do administrador.' })
    }

    const { data: convitesHoje, error: limiteError } = await supabaseAdmin.rpc('convites_empresa_ultimas_24h', {
      p_empresa_id: empresaId,
    })
    if (!limiteError && typeof convitesHoje === 'number' && convitesHoje >= LIMITE_CONVITES_DIA) {
      return response(429, {
        erro: `Limite de ${LIMITE_CONVITES_DIA} convites por dia atingido. Tente novamente amanhã ou fale com a DIAVICON.`,
      })
    }

    const senhaProvisoria = gerarSenhaProvisoria()
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: senhaProvisoria,
      email_confirm: true,
      app_metadata: { onboarding: 'invite' },
    })
    if (authError || !authData.user) {
      const jaExiste = (authError as { code?: string; status?: number } | null)?.code === 'email_exists' ||
        /already|registered|exists/i.test(authError?.message ?? '')
      if (jaExiste) return response(409, { erro: 'Este e-mail já tem uma conta na DIAVICON.' })
      throw authError ?? new Error('Não foi possível criar o usuário.')
    }

    const invitedUserId = authData.user.id
    const { error: profileError } = await supabaseAdmin.rpc('create_invited_profile_if_capacity', {
      p_user_id: invitedUserId,
      p_empresa_id: empresaId,
      p_nome: nome,
      p_sobrenome: sobrenome,
      p_cargo: cargo,
      p_email: email,
    })
    if (profileError) {
      await supabaseAdmin.auth.admin.deleteUser(invitedUserId)
      throw profileError
    }

    if (projetoId) {
      const { error: equipeError } = await supabaseAdmin
        .from('projeto_equipe_interna')
        .insert({
          projeto_id: projetoId,
          usuario_id: invitedUserId,
          empresa_id: empresaId,
          ativo: true,
          is_gestor: false,
        })

      if (equipeError) {
        await supabaseAdmin.from('usuarios').delete().eq('id', invitedUserId)
        await supabaseAdmin.auth.admin.deleteUser(invitedUserId)
        throw equipeError
      }
    }

    await supabaseAdmin.rpc('registrar_evento_auditoria', {
      p_ator: userData.user.id,
      p_acao: 'convite.enviado',
      p_tabela: 'usuarios',
      p_id: invitedUserId,
      p_empresa: empresaId,
      p_detalhes: null,
    })

    // O e-mail é o último passo de propósito: a conta já existe e a senha já
    // está na resposta, então uma falha de envio não pode desfazer o convite.
    // Quem chamou mostra a senha na tela e avisa que o e-mail não saiu.
    // Cinto de segurança: nenhuma falha do e-mail pode virar erro do convite,
    // que a esta altura já criou a conta. Antes, um erro inesperado aqui
    // subia até o catch lá embaixo e o app dizia que o convite falhou — com
    // o colaborador já criado no banco.
    let envio: ResultadoEmail
    try {
      envio = await enviarSenhaProvisoria(email, nome, senhaProvisoria)
    } catch (erroEmail) {
      const motivo = erroEmail instanceof Error ? erroEmail.message : String(erroEmail)
      envio = { enviado: false, erro: `Falha inesperada ao enviar o e-mail: ${motivo}` }
    }

    // O motivo técnico (servidor, usuário, resposta do provedor) fica só no
    // log da função; o app recebe uma mensagem sem detalhes internos.
    if (!envio.enviado) console.error('convidar-funcionario: e-mail não enviado:', envio.erro)

    return response(200, {
      sucesso: true,
      senhaProvisoria,
      emailEnviado: envio.enviado,
      emailErro: envio.enviado
        ? null
        : 'O e-mail com a senha não pôde ser enviado agora. Entregue a senha provisória ao colaborador por outro meio.',
      mensagem: 'Usuário criado com sucesso!',
    })
  } catch (error) {
    const code = errorCode(error)
    console.error('convidar-funcionario:', code, errorMessage(error))
    // P0001/P0002 são mensagens escritas por nós no banco (ex.: limite de
    // usuários do plano) e podem ir para a tela. O resto fica só no log.
    if (code === 'P0001' || code === 'P0002') {
      return response(code === 'P0002' ? 404 : 409, { erro: errorMessage(error) })
    }
    if (code === '23505') return response(409, { erro: 'Este colaborador já está cadastrado.' })
    return response(400, { erro: 'Não foi possível criar o convite. Tente novamente em instantes.' })
  }
})
