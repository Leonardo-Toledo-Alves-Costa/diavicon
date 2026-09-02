import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function gerarSenhaProvisoria() {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  const bytes = new Uint8Array(8)
  crypto.getRandomValues(bytes)
  let senha = ''
  for (let i = 0; i < 8; i++) senha += chars.charAt(bytes[i] % chars.length)
  return `${senha}@1A`
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

    const email = text(body.email)
    const nome = text(body.nome)
    const sobrenome = text(body.sobrenome)
    const cargo = text(body.cargo)
    const legacyCompanyId = text(body.empresa_id)
    const projetoId = text(body.projeto_id)
    if (!email || !nome || !sobrenome || !cargo || !legacyCompanyId) {
      return response(400, { erro: 'Dados do convite inválidos.' })
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

    const senhaProvisoria = gerarSenhaProvisoria()
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: senhaProvisoria,
      email_confirm: true,
      app_metadata: { onboarding: 'invite' },
    })
    if (authError || !authData.user) throw authError ?? new Error('Não foi possível criar o usuário.')

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

    return response(200, {
      sucesso: true,
      senhaProvisoria,
      mensagem: 'Usuário criado com sucesso!',
    })
  } catch (error) {
    const message = errorMessage(error)
    const code = errorCode(error)
    const status = code === 'P0001' || code === '23505' ? 409 : code === 'P0002' ? 404 : 400
    return response(status, { erro: message })
  }
})
