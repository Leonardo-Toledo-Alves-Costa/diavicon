import { createClient, type User } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type JsonRecord = Record<string, unknown>
type AdminClient = ReturnType<typeof createClient>

function jsonResponse(status: number, payload: unknown) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function asText(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null
}

function isRecord(value: unknown): value is JsonRecord {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (isRecord(error) && typeof error.message === 'string' && error.message.trim()) return error.message
  return 'Erro interno.'
}

function errorStatus(error: unknown): number {
  const code = isRecord(error) && typeof error.code === 'string' ? error.code : null
  if (code === '23505' || code === 'P0001') return 409
  if (code === '42501') return 403
  if (code === 'P0002') return 404
  if (code === '22023') return 400
  return 400
}

async function getAuthenticatedUser(req: Request): Promise<
  { user: User } | { error: Response }
> {
  const authorization = req.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    return { error: jsonResponse(401, { erro: 'Autenticação obrigatória.' }) }
  }

  const supabaseUser = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authorization } } },
  )
  const { data, error } = await supabaseUser.auth.getUser()
  if (error || !data.user) {
    return { error: jsonResponse(401, { erro: 'Sessão inválida.' }) }
  }

  return { user: data.user }
}

function adminClient(): AdminClient {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )
}

function cnpjIsValid(value: string): boolean {
  const digits = value.replace(/\D/g, '')
  if (digits.length !== 14 || /^(\d)\1{13}$/.test(digits)) return false

  const calculate = (base: string, weights: number[]) => {
    const sum = [...base].reduce((total, digit, index) => total + Number(digit) * weights[index], 0)
    const remainder = sum % 11
    return remainder < 2 ? 0 : 11 - remainder
  }

  const first = calculate(digits.slice(0, 12), [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  const second = calculate(digits.slice(0, 12) + first, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
  return first === Number(digits[12]) && second === Number(digits[13])
}

function formatCnpj(value: string): string {
  const digits = value.replace(/\D/g, '')
  return `${digits.slice(0, 2)}.${digits.slice(2, 5)}.${digits.slice(5, 8)}/${digits.slice(8, 12)}-${digits.slice(12)}`
}

async function loadProfile(admin: AdminClient, userId: string) {
  const { data, error } = await admin
    .from('usuarios')
    .select('id, empresa_id, ativo, convite_pendente, is_admin_empresa, is_admin, nome, sobrenome, cargo, foto_url, email, criado_em')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  return data
}

function companyAdminCanAct(actor: JsonRecord | null): boolean {
  return Boolean(
    actor &&
      actor.empresa_id &&
      actor.ativo === true &&
      (actor.is_admin_empresa === true || actor.is_admin === true),
  )
}

async function createCompany(userId: string, body: JsonRecord) {
  const admin = adminClient()
  const profile = await loadProfile(admin, userId)
  if (!profile) return jsonResponse(404, { erro: 'Perfil do usuário não encontrado.' })
  if (profile.empresa_id != null) {
    return jsonResponse(409, { erro: 'Este usuário já está vinculado a uma empresa.' })
  }

  const data = body.dados_empresa
  if (!isRecord(data)) return jsonResponse(400, { erro: 'Dados da empresa inválidos.' })

  const nome = asText(data.nome)
  const cnpj = asText(data.cnpj)
  if (!nome || !cnpj) {
    return jsonResponse(400, { erro: 'Nome e CNPJ da empresa são obrigatórios.' })
  }
  if (!cnpjIsValid(cnpj)) {
    return jsonResponse(400, { erro: 'CNPJ inválido.' })
  }

  const address: JsonRecord = {
    endereco: data.rua ?? null,
    cidade: data.cidade ?? null,
    estado: data.estado ?? null,
    cep: data.cep ?? null,
    bairro: data.bairro ?? null,
    numero: data.numero ?? null,
    complemento: data.complemento ?? null,
    pais: data.pais ?? 'Brasil',
  }
  // Deliberately omit every client-supplied plan identifier.  The RPC selects
  // the single server-configured default plan inside its transaction.
  const company: JsonRecord = {
    nome,
    cnpj: formatCnpj(cnpj),
    tamanho: data.tamanho ?? null,
    tipo: asText(data.tipo) ?? 'Profissional',
    foto_url: data.foto_url ?? null,
    site: data.site ?? null,
    linkedin: data.linkedin ?? null,
  }

  const { data: companyId, error } = await admin.rpc('create_company_for_user', {
    p_user_id: userId,
    p_company: company,
    p_address: address,
    p_cargo: asText(body.cargo),
    p_titulo_principal: asText(body.titulo_principal),
  })
  if (error) throw error

  return jsonResponse(200, { sucesso: true, empresa_id: companyId })
}

async function completeProfile(
  userId: string,
  body: JsonRecord,
  authUser: User,
) {
  const admin = adminClient()
  const profile = await loadProfile(admin, userId)
  if (!profile || profile.empresa_id == null) {
    return jsonResponse(409, { erro: 'Perfil de convite não encontrado.' })
  }
  const originalCompanyId = profile.empresa_id as string

  const onboardingState = authUser.app_metadata?.onboarding
  if (onboardingState === 'completed' && profile.ativo === true && profile.convite_pendente === false) {
    return jsonResponse(200, { sucesso: true })
  }
  if (onboardingState !== 'invite' || profile.convite_pendente !== true || profile.ativo !== false) {
    return jsonResponse(403, { erro: 'Este perfil não está aguardando conclusão de convite.' })
  }

  const nome = asText(body.nome)
  const sobrenome = asText(body.sobrenome)
  const celular = asText(body.celular)
  const fotoUrl = asText(body.foto_url)
  if (!nome || !sobrenome || !celular || !fotoUrl) {
    return jsonResponse(400, { erro: 'Nome, sobrenome, celular e foto são obrigatórios.' })
  }

  const { data: updated, error: updateError } = await admin
    .from('usuarios')
    .update({ nome, sobrenome, celular, foto_url: fotoUrl, ativo: true, convite_pendente: false })
    .eq('id', userId)
    .eq('convite_pendente', true)
    .eq('ativo', false)
    .select('id')
    .maybeSingle()
  if (updateError) throw updateError
  if (!updated) return jsonResponse(409, { erro: 'O convite já foi concluído ou cancelado.' })

  const appMetadata = { ...(authUser.app_metadata ?? {}), onboarding: 'completed' }
  const { error: authUpdateError } = await admin.auth.admin.updateUserById(userId, { app_metadata: appMetadata })
  if (authUpdateError) {
    // Only compensate the exact state produced above.  A concurrent
    // cancellation/deactivation or relink must remain the newest state.
    await admin
      .from('usuarios')
      .update({ ativo: false, convite_pendente: true })
      .eq('id', userId)
      .eq('empresa_id', originalCompanyId)
      .eq('ativo', true)
      .eq('convite_pendente', false)
      .select('id')
      .maybeSingle()
    throw authUpdateError
  }

  return jsonResponse(200, { sucesso: true })
}

async function updateAuthBan(admin: AdminClient, userId: string, banned: boolean) {
  const { error } = await admin.auth.admin.updateUserById(userId, {
    ban_duration: banned ? '876000h' : 'none',
  })
  if (error) throw error
}

async function manageCollaborator(userId: string, body: JsonRecord) {
  const admin = adminClient()
  const operation = asText(body.operation)
  const targetId = asText(body.usuario_id)
  if (!operation || !targetId) return jsonResponse(400, { erro: 'Dados da operação inválidos.' })

  const actor = await loadProfile(admin, userId)
  if (!companyAdminCanAct(actor)) {
    return jsonResponse(403, { erro: 'Apenas um administrador ativo da empresa pode gerenciar colaboradores.' })
  }
  const companyId = actor?.empresa_id as string
  const requestedCompanyId = asText(body.empresa_id)
  if (requestedCompanyId && requestedCompanyId !== companyId) {
    return jsonResponse(403, { erro: 'A empresa da sessão não corresponde à operação.' })
  }
  if (targetId === userId) return jsonResponse(400, { erro: 'Você não pode alterar o próprio acesso por esta operação.' })

  const target = await loadProfile(admin, targetId)
  if (!target || target.empresa_id !== companyId) {
    return jsonResponse(404, { erro: 'Colaborador não encontrado na empresa.' })
  }
  if (target.is_admin_empresa === true) {
    return jsonResponse(403, { erro: 'O administrador principal não pode ser alterado por esta operação.' })
  }

  switch (operation) {
    case 'set_admin': {
      if (typeof body.is_admin !== 'boolean') return jsonResponse(400, { erro: 'O valor de administrador é inválido.' })
      if (target.ativo !== true) return jsonResponse(409, { erro: 'Somente colaboradores ativos podem ser administradores.' })
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ is_admin: body.is_admin })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .eq('is_admin_empresa', false)
        .select('id')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      return jsonResponse(200, { sucesso: true })
    }

    case 'deactivate': {
      const previous = {
        ativo: target.ativo,
        convite_pendente: target.convite_pendente,
        is_admin: target.is_admin,
      }
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ ativo: false, convite_pendente: false, is_admin: false })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .eq('is_admin_empresa', false)
        .select('id')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      try {
        await updateAuthBan(admin, targetId, true)
      } catch (authError) {
        await admin
          .from('usuarios')
          .update(previous)
          .eq('id', targetId)
          .eq('empresa_id', companyId)
          .eq('is_admin_empresa', false)
          .eq('ativo', false)
          .eq('convite_pendente', false)
          .eq('is_admin', false)
          .select('id')
          .maybeSingle()
        throw authError
      }
      return jsonResponse(200, { sucesso: true })
    }

    case 'reactivate': {
      const { data: reactivated, error: rpcError } = await admin.rpc('reactivate_user_if_capacity', {
        p_user_id: targetId,
        p_empresa_id: companyId,
      })
      if (rpcError) throw rpcError
      if (reactivated !== true) return jsonResponse(409, { erro: 'O colaborador não está inativo.' })
      try {
        await updateAuthBan(admin, targetId, false)
      } catch (authError) {
        await admin
          .from('usuarios')
          .update({ ativo: false, convite_pendente: false })
          .eq('id', targetId)
          .eq('empresa_id', companyId)
          .eq('is_admin_empresa', false)
          .eq('ativo', true)
          .eq('convite_pendente', false)
          .select('id')
          .maybeSingle()
        throw authError
      }
      return jsonResponse(200, { sucesso: true })
    }

    case 'unlink': {
      if (target.convite_pendente === true) {
        const { error } = await admin.auth.admin.deleteUser(targetId)
        if (error) throw error
        return jsonResponse(200, { sucesso: true })
      }

      const previous = {
        empresa_id: target.empresa_id,
        ativo: target.ativo,
        convite_pendente: target.convite_pendente,
        is_admin_empresa: target.is_admin_empresa,
        is_admin: target.is_admin,
      }
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ empresa_id: null, ativo: true, convite_pendente: false, is_admin_empresa: false, is_admin: false })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .eq('is_admin_empresa', false)
        .select('id')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      try {
        await updateAuthBan(admin, targetId, false)
      } catch (authError) {
        await admin
          .from('usuarios')
          .update(previous)
          .eq('id', targetId)
          .is('empresa_id', null)
          .eq('ativo', true)
          .eq('convite_pendente', false)
          .eq('is_admin_empresa', false)
          .eq('is_admin', false)
          .select('id')
          .maybeSingle()
        throw authError
      }
      return jsonResponse(200, { sucesso: true })
    }

    default:
      return jsonResponse(400, { erro: 'Operação de colaborador desconhecida.' })
  }
}

async function transferPrimaryAdmin(userId: string, body: JsonRecord) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!actor || actor.ativo !== true || actor.is_admin_empresa !== true || !actor.empresa_id) {
    return jsonResponse(403, { erro: 'Apenas o administrador principal ativo pode transferir a administração.' })
  }
  const targetId = asText(body.usuario_id) ?? asText(body.target_id)
  if (!targetId || targetId === userId) return jsonResponse(400, { erro: 'Alvo de transferência inválido.' })

  const { error } = await admin.rpc('transfer_primary_admin', {
    p_empresa_id: actor.empresa_id,
    p_current_primary_id: userId,
    p_target_id: targetId,
  })
  if (error) throw error
  return jsonResponse(200, { sucesso: true })
}

async function listCompanyColleagues(userId: string) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!actor || actor.ativo !== true || !actor.empresa_id) {
    return jsonResponse(403, { erro: 'Usuário ativo e vinculado à empresa é obrigatório.' })
  }
  const { data, error } = await admin
    .from('usuarios')
    .select('id, nome, sobrenome, cargo, foto_url')
    .eq('empresa_id', actor.empresa_id)
    .eq('ativo', true)
    .neq('id', userId)
    .order('nome', { ascending: true })
  if (error) throw error
  return jsonResponse(200, { colegas: data ?? [] })
}

async function listCompanyMembersAdmin(userId: string) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!companyAdminCanAct(actor)) {
    return jsonResponse(403, { erro: 'Apenas um administrador ativo da empresa pode consultar os membros.' })
  }
  const { data, error } = await admin
    .from('usuarios')
    .select('id, nome, sobrenome, cargo, foto_url, email, ativo, convite_pendente, is_admin_empresa, is_admin')
    .eq('empresa_id', actor?.empresa_id)
    .order('is_admin_empresa', { ascending: false })
    .order('nome', { ascending: true })
  if (error) throw error

  const membros = (data ?? []).map((member) => ({
    id: member.id,
    nome: member.nome,
    sobrenome: member.sobrenome,
    cargo: member.cargo,
    foto_url: member.foto_url,
    email: member.email,
    status: member.convite_pendente === true ? 'convidado' : member.ativo === true ? 'ativo' : 'inativo',
    is_admin_empresa: member.is_admin_empresa === true,
    is_admin: member.is_admin === true,
  }))
  return jsonResponse(200, { membros })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse(405, { erro: 'Método não permitido.' })

  try {
    const auth = await getAuthenticatedUser(req)
    if ('error' in auth) return auth.error

    const body = await req.json()
    if (!isRecord(body)) return jsonResponse(400, { erro: 'Corpo da requisição inválido.' })
    const action = asText(body.action)
    if (!action) return jsonResponse(400, { erro: 'Ação obrigatória.' })

    if (action === 'create_company') return await createCompany(auth.user.id, body)
    if (action === 'complete_profile') return await completeProfile(auth.user.id, body, auth.user)
    if (action === 'manage_collaborator') return await manageCollaborator(auth.user.id, body)
    if (action === 'transfer_primary_admin') return await transferPrimaryAdmin(auth.user.id, body)
    if (action === 'list_company_colleagues') return await listCompanyColleagues(auth.user.id)
    if (action === 'list_company_members_admin') return await listCompanyMembersAdmin(auth.user.id)
    return jsonResponse(400, { erro: 'Ação desconhecida.' })
  } catch (error) {
    return jsonResponse(errorStatus(error), { erro: errorMessage(error) })
  }
})
