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

async function completeSelfRegistration(
  userId: string,
  body: JsonRecord,
  authUser: User,
) {
  if (!authUser.email || !authUser.email_confirmed_at) {
    return jsonResponse(403, { erro: 'Confirme o e-mail antes de concluir o cadastro.' })
  }

  const profileType = asText(body.perfil_tipo)
  const profile = body.perfil
  const address = body.endereco
  const company = body.empresa
  let companyPayload: JsonRecord | null = null
  if (!profileType || !isRecord(profile) || !isRecord(address)) {
    return jsonResponse(400, { erro: 'Dados de cadastro inválidos.' })
  }
  if (profileType.toLowerCase() === 'empresa' || profileType.toLowerCase() === 'company') {
    if (!isRecord(company)) return jsonResponse(400, { erro: 'Dados da empresa são obrigatórios.' })
    const cnpj = asText(company.cnpj)
    if (!cnpj || !cnpjIsValid(cnpj)) return jsonResponse(400, { erro: 'CNPJ inválido.' })
    if (!isRecord(company.endereco)) {
      return jsonResponse(400, { erro: 'Endereço comercial é obrigatório.' })
    }
    // Keep the normalized CNPJ and the commercial address server-bound in the
    // payload passed to the service-role SQL function.
    companyPayload = { ...company, cnpj: formatCnpj(cnpj) }
  }

  const admin = adminClient()
  const { data, error } = await admin.rpc('complete_self_registration', {
    p_user_id: userId,
    // The SQL function compares this with auth.users.email.  The value comes
    // from the validated session and is never accepted from the request body.
    p_email: authUser.email,
    p_profile_type: profileType,
    p_profile: profile,
    p_address: address,
    p_company: companyPayload,
  })
  if (error) throw error

  return jsonResponse(200, isRecord(data) ? { sucesso: true, ...data } : { sucesso: true })
}

async function cleanupGoogleOrphan(userId: string, authUser: User) {
  if (authUser.id !== userId) return jsonResponse(403, { erro: 'Usuário inválido.' })

  const admin = adminClient()
  const { data: profile, error: profileError } = await admin
    .from('usuarios')
    .select('id')
    .eq('id', userId)
    .maybeSingle()
  if (profileError) throw profileError
  if (profile) return jsonResponse(200, { sucesso: true, excluida: false })

  const { data: authData, error: authError } = await admin.auth.admin.getUserById(userId)
  if (authError || !authData.user) throw authError ?? new Error('Usuário não encontrado.')
  const identities = authData.user.identities ?? []
  const providers = identities.map((identity) => identity.provider).filter(Boolean)
  const createdAt = Date.parse(authData.user.created_at)
  const isRecent = Number.isFinite(createdAt) && Date.now() - createdAt <= 15 * 60 * 1000

  // Only remove a just-created account whose sole identity is Google.  This
  // preserves existing e-mail/password accounts and linked identities.
  if (providers.length !== 1 || providers[0] !== 'google' || !isRecent) {
    return jsonResponse(200, { sucesso: true, excluida: false })
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId)
  if (deleteError) throw deleteError
  return jsonResponse(200, { sucesso: true, excluida: true })
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
  // Cargo e nível não são acesso: o Gestor pode corrigir os próprios.
  if (targetId === userId && operation !== 'set_cargo') {
    return jsonResponse(400, { erro: 'Você não pode alterar o próprio acesso por esta operação.' })
  }

  const target = await loadProfile(admin, targetId)
  if (!target || target.empresa_id !== companyId) {
    return jsonResponse(404, { erro: 'Colaborador não encontrado na empresa.' })
  }
  // Trava do Gestor. As escritas abaixo não repetem esta regra como filtro
  // (`.eq('is_admin_empresa', false)`), porque a coluna pode estar NULA — e aí
  // o filtro não casava com a linha, a escrita não mudava nada e a resposta
  // era um "alterado por outra operação" que não dizia nada.
  //
  // Um Gestor pode mexer em outro Gestor: tirar o papel, suspender o acesso e
  // até excluir. Um admin comum, não. E nem toda operação faz sentido sobre um
  // Gestor — "admin" e "vê o painel" já vêm junto com o papel.
  if (target.is_admin_empresa === true) {
    if (actor?.is_admin_empresa !== true) {
      return jsonResponse(403, { erro: 'Apenas um Gestor da empresa pode alterar outro Gestor.' })
    }
    const permitidasSobreGestor = ['set_admin_empresa', 'set_cargo', 'deactivate', 'reactivate', 'unlink', 'delete_permanently']
    if (!permitidasSobreGestor.includes(operation)) {
      return jsonResponse(409, { erro: 'O papel de Gestor já inclui essa permissão.' })
    }
    // Tirar um Gestor de circulação não pode deixar a empresa sem nenhum.
    // ('set_admin_empresa' tem a própria contagem, logo abaixo.)
    if (operation === 'deactivate' || operation === 'unlink' || operation === 'delete_permanently') {
      const { count, error: contagemErro } = await admin
        .from('usuarios')
        .select('id', { count: 'exact', head: true })
        .eq('empresa_id', companyId)
        .eq('is_admin_empresa', true)
        .eq('ativo', true)
        .neq('id', targetId)
      if (contagemErro) throw contagemErro
      if (!count) return jsonResponse(409, { erro: 'A empresa precisa manter ao menos um Gestor ativo.' })
    }
  }

  switch (operation) {
    case 'set_admin_empresa': {
      // Concede ou revoga o papel de Gestor da empresa (is_admin_empresa).
      // Diferente de 'set_admin': mais de um colaborador pode ser Gestor ao
      // mesmo tempo (não é mais um cargo único — ver migração
      // 20260917240000_multi_gestor_empresa.sql). Só um Gestor ativo pode
      // conceder/revogar esse papel, e a empresa precisa manter sempre pelo
      // menos um.
      if (actor?.is_admin_empresa !== true) {
        return jsonResponse(403, { erro: 'Apenas um Gestor da empresa pode conceder ou revogar esse papel.' })
      }
      if (typeof body.is_admin_empresa !== 'boolean') return jsonResponse(400, { erro: 'O valor é inválido.' })
      if (target.ativo === false) return jsonResponse(409, { erro: 'Somente colaboradores ativos podem ser Gestor da empresa.' })

      if (body.is_admin_empresa === false) {
        const { count, error: countError } = await admin
          .from('usuarios')
          .select('id', { count: 'exact', head: true })
          .eq('empresa_id', companyId)
          .eq('is_admin_empresa', true)
          .neq('id', targetId)
        if (countError) throw countError
        if (!count) return jsonResponse(409, { erro: 'A empresa precisa manter ao menos um Gestor.' })
      }

      const { data: updated, error } = await admin
        .from('usuarios')
        .update({
          is_admin_empresa: body.is_admin_empresa,
          // Virar Gestor já inclui a permissão de admin comum; perder o
          // papel de Gestor não tira o admin comum automaticamente.
          ...(body.is_admin_empresa === true ? { is_admin: true } : {}),
        })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .select('id')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      return jsonResponse(200, { sucesso: true })
    }

    case 'set_admin': {
      if (typeof body.is_admin !== 'boolean') return jsonResponse(400, { erro: 'O valor de administrador é inválido.' })
      if (target.ativo === false) return jsonResponse(409, { erro: 'Somente colaboradores ativos podem ser administradores.' })
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ is_admin: body.is_admin })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .select('id, is_admin')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      return jsonResponse(200, { sucesso: true })
    }

    case 'set_cargo': {
      // Cargo (texto livre) e nível (titulo_principal: Júnior, Pleno…). Só o
      // Gestor mexe nisso — é informação de RH, não de acesso.
      if (actor?.is_admin_empresa !== true) {
        return jsonResponse(403, { erro: 'Apenas um Gestor da empresa pode editar cargo e nível.' })
      }
      const cargo = asText(body.cargo)
      const nivel = asText(body.nivel)
      if (!cargo) return jsonResponse(400, { erro: 'Informe o cargo.' })
      if (cargo.length > 80) return jsonResponse(400, { erro: 'O cargo pode ter no máximo 80 caracteres.' })
      if (nivel && nivel.length > 40) return jsonResponse(400, { erro: 'O nível pode ter no máximo 40 caracteres.' })
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ cargo, titulo_principal: nivel })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .select('id')
        .maybeSingle()
      if (error) throw error
      if (!updated) return jsonResponse(409, { erro: 'O colaborador foi alterado por outra operação.' })
      return jsonResponse(200, { sucesso: true })
    }

    case 'set_pode_visualizar': {
      // Concede/remove acesso só de VISUALIZAÇÃO ao painel da empresa (não
      // confundir com 'set_admin', que dá permissão de gerenciar
      // colaboradores/serviços/etc.) — usado por colaboradores comuns que
      // precisam só acompanhar o painel sem virar administrador.
      if (typeof body.pode_visualizar !== 'boolean') return jsonResponse(400, { erro: 'O valor é inválido.' })
      if (target.ativo === false) return jsonResponse(409, { erro: 'Somente colaboradores ativos podem visualizar o painel.' })
      const { data: updated, error } = await admin
        .from('usuarios')
        .update({ pode_visualizar_empresa: body.pode_visualizar })
        .eq('id', targetId)
        .eq('empresa_id', companyId)
        .select('id, pode_visualizar_empresa')
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
          .eq('is_admin', false)
          .select('id')
          .maybeSingle()
        throw authError
      }
      return jsonResponse(200, { sucesso: true })
    }

    case 'delete_permanently': {
      // 'unlink' (acima) só desvincula da empresa e, contraintuitivamente,
      // reativa a conta (updateAuthBan(..., false)) — a linha de `usuarios`
      // e o registro em auth.users continuam existindo, então reconvidar
      // esse e-mail depois falha (createUser rejeita e-mail já cadastrado).
      // Esta operação é a exclusão definitiva de verdade: apaga a linha de
      // `usuarios` e o usuário em auth.users, liberando o e-mail pra um novo
      // convite. Vale para colaborador ativo ou suspenso — obrigar a
      // suspender antes só criava um passo a mais para o administrador, que
      // já confirma a exclusão na tela. O Gestor continua protegido pela
      // trava lá em cima.
      // auth.users primeiro: é o passo que libera o e-mail pra reconvite —
      // se falhar, nada foi apagado ainda. Se a linha de `usuarios` falhar
      // depois, sobra um perfil órfão sem conta de login, inofensivo.
      await admin.rpc('preparar_exclusao_conta', { p_usuario_id: targetId })
      await auditar(admin, userId, 'conta.excluida_pelo_administrador', 'usuarios', targetId, companyId)
      const { error: authError } = await admin.auth.admin.deleteUser(targetId)
      if (authError) throw authError

      const { error: deleteRowError } = await admin
        .from('usuarios')
        .delete()
        .eq('id', targetId)
        .eq('empresa_id', companyId)
      if (deleteRowError) throw deleteRowError

      await admin.rpc('enfileirar_arquivos_pessoais', { p_usuario_id: targetId })
      await esvaziarFilaDeArquivos(admin)
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
    .select('id, nome, sobrenome, cargo, titulo_principal, foto_url, email, ativo, convite_pendente, is_admin_empresa, is_admin, pode_visualizar_empresa')
    .eq('empresa_id', actor?.empresa_id)
    .order('is_admin_empresa', { ascending: false })
    .order('nome', { ascending: true })
  if (error) throw error

  const membros = (data ?? []).map((member) => ({
    id: member.id,
    nome: member.nome,
    sobrenome: member.sobrenome,
    cargo: member.cargo,
    titulo_principal: member.titulo_principal,
    foto_url: member.foto_url,
    email: member.email,
    status: member.convite_pendente === true ? 'convidado' : member.ativo === true ? 'ativo' : 'inativo',
    is_admin_empresa: member.is_admin_empresa === true,
    is_admin: member.is_admin === true,
    pode_visualizar_empresa: member.pode_visualizar_empresa === true,
  }))
  return jsonResponse(200, { membros })
}

// ---------------------------------------------------------------------------
// Exclusão de empresa e controle de empresas (painel da DIAVICON)
// ---------------------------------------------------------------------------

// A DIAVICON nunca pode ser apagada; o SQL (excluir_empresa_completa) também recusa.
const DIAVICON_EMPRESA_ID = '96b9a6b9-32d0-453e-9f69-74a2691ac5cc'

function normalizarNome(value: unknown): string {
  return (asText(value) ?? '').trim().replace(/\s+/g, ' ').toLocaleLowerCase('pt-BR')
}

function isPrimaryAdmin(actor: JsonRecord | null): boolean {
  return Boolean(actor && actor.ativo === true && actor.is_admin_empresa === true && actor.empresa_id)
}

function isDiaviconAdmin(actor: JsonRecord | null): boolean {
  return isPrimaryAdmin(actor) && actor?.empresa_id === DIAVICON_EMPRESA_ID
}

// Apaga dados (SQL), arquivos (Storage) e contas de login (auth.users), nessa
// ordem. Se o SQL falhar, nada foi apagado. Falhas de arquivo ou de login
// depois disso não desfazem nada: voltam na resposta para a equipe limpar.
async function removeCompanyEverything(admin: AdminClient, empresaId: string) {
  if (empresaId === DIAVICON_EMPRESA_ID) {
    return jsonResponse(403, { erro: 'A empresa DIAVICON não pode ser excluída.' })
  }

  const { data, error } = await admin.rpc('excluir_empresa_completa', { p_empresa_id: empresaId })
  if (error) throw error
  const resultado = isRecord(data) ? data : {}

  const arquivos = Array.isArray(resultado.arquivos) ? resultado.arquivos : []
  const porBucket = new Map<string, string[]>()
  for (const arquivo of arquivos) {
    if (!isRecord(arquivo)) continue
    const bucket = asText(arquivo.bucket)
    const nome = asText(arquivo.nome)
    if (!bucket || !nome) continue
    porBucket.set(bucket, [...(porBucket.get(bucket) ?? []), nome])
  }
  let arquivosComFalha = 0
  for (const [bucket, nomes] of porBucket) {
    for (let i = 0; i < nomes.length; i += 100) {
      const lote = nomes.slice(i, i + 100)
      const { error: storageError } = await admin.storage.from(bucket).remove(lote)
      if (storageError) arquivosComFalha += lote.length
    }
  }

  const usuarios = Array.isArray(resultado.usuarios) ? resultado.usuarios : []
  const loginsComFalha: string[] = []
  for (const usuarioId of usuarios) {
    const id = asText(usuarioId)
    if (!id) continue
    const { error: authError } = await admin.auth.admin.deleteUser(id)
    // Conta já inexistente não é falha.
    if (authError && !/not.?found/i.test(authError.message ?? '')) loginsComFalha.push(id)
  }

  return jsonResponse(200, {
    sucesso: true,
    usuarios_excluidos: usuarios.length,
    arquivos_excluidos: arquivos.length - arquivosComFalha,
    arquivos_com_falha: arquivosComFalha,
    logins_com_falha: loginsComFalha,
  })
}

// O administrador principal apaga a própria empresa, a conta dele e as dos
// colaboradores. Exige digitar o nome da empresa (conferido aqui também).
async function deleteOwnCompany(userId: string, body: JsonRecord) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!isPrimaryAdmin(actor)) {
    return jsonResponse(403, { erro: 'Apenas o administrador principal da empresa pode excluí-la.' })
  }
  const empresaId = String(actor?.empresa_id)
  if (empresaId === DIAVICON_EMPRESA_ID) {
    return jsonResponse(403, { erro: 'A empresa DIAVICON não pode ser excluída.' })
  }

  const { data: empresa, error } = await admin.from('empresas').select('nome').eq('id', empresaId).maybeSingle()
  if (error) throw error
  if (!empresa) return jsonResponse(404, { erro: 'Empresa não encontrada.' })
  if (normalizarNome(body.confirmacao_nome) !== normalizarNome(empresa.nome)) {
    return jsonResponse(400, { erro: 'O nome digitado não confere com o nome da empresa.' })
  }

  return await removeCompanyEverything(admin, empresaId)
}

async function platformListCompanies(userId: string) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!isDiaviconAdmin(actor)) {
    return jsonResponse(403, { erro: 'Acesso restrito à administração da DIAVICON.' })
  }
  const { data, error } = await admin.rpc('plataforma_resumo_empresas')
  if (error) throw error
  const empresas = (Array.isArray(data) ? data : []).map((empresa: JsonRecord) => ({
    ...empresa,
    protegida: empresa.id === DIAVICON_EMPRESA_ID,
  }))
  return jsonResponse(200, { empresas })
}

async function platformDeleteCompany(userId: string, body: JsonRecord) {
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  if (!isDiaviconAdmin(actor)) {
    return jsonResponse(403, { erro: 'Acesso restrito à administração da DIAVICON.' })
  }
  const empresaId = asText(body.empresa_id)
  if (!empresaId) return jsonResponse(400, { erro: 'Empresa não informada.' })
  if (empresaId === DIAVICON_EMPRESA_ID) {
    return jsonResponse(403, { erro: 'A empresa DIAVICON não pode ser excluída.' })
  }

  const { data: empresa, error } = await admin.from('empresas').select('nome').eq('id', empresaId).maybeSingle()
  if (error) throw error
  if (!empresa) return jsonResponse(404, { erro: 'Empresa não encontrada.' })
  if (normalizarNome(body.confirmacao_nome) !== normalizarNome(empresa.nome)) {
    return jsonResponse(400, { erro: 'O nome digitado não confere com o nome da empresa.' })
  }

  return await removeCompanyEverything(admin, empresaId)
}

// ---------------------------------------------------------------------------
// LGPD: exclusão da própria conta, auditoria e fila de arquivos a apagar
// ---------------------------------------------------------------------------

// Registro de auditoria (private.auditoria). Nunca derruba a operação.
async function auditar(
  admin: AdminClient,
  ator: string | null,
  acao: string,
  tabela: string | null,
  alvoId: string | null,
  empresaId: string | null,
  detalhes: JsonRecord | null = null,
) {
  const { error } = await admin.rpc('registrar_evento_auditoria', {
    p_ator: ator,
    p_acao: acao,
    p_tabela: tabela,
    p_id: alvoId,
    p_empresa: empresaId,
    p_detalhes: detalhes,
  })
  if (error) console.warn('auditoria:', error.message)
}

// Apaga do Storage os arquivos que o banco pôs na fila
// (private.arquivos_para_apagar): fotos de perfil e do feed de contas
// excluídas, inclusive pela retenção automática. Só confirma na fila o que
// o Storage apagou de fato.
async function esvaziarFilaDeArquivos(admin: AdminClient): Promise<number> {
  const { data, error } = await admin.rpc('arquivos_para_apagar_pegar', { p_limite: 500 })
  if (error || !Array.isArray(data)) {
    if (error) console.warn('fila de arquivos:', error.message)
    return 0
  }
  const porBucket = new Map<string, string[]>()
  for (const item of data) {
    if (!isRecord(item)) continue
    const bucket = asText(item.bucket_id)
    const nome = asText(item.nome)
    if (!bucket || !nome) continue
    porBucket.set(bucket, [...(porBucket.get(bucket) ?? []), nome])
  }
  let apagados = 0
  for (const [bucket, nomes] of porBucket) {
    for (let i = 0; i < nomes.length; i += 100) {
      const lote = nomes.slice(i, i + 100)
      const { error: storageError } = await admin.storage.from(bucket).remove(lote)
      if (storageError) continue
      apagados += lote.length
      await admin.rpc('arquivos_para_apagar_confirmar', { p_bucket: bucket, p_nomes: lote })
    }
  }
  return apagados
}

// O próprio usuário exclui a conta (Perfil > Minha conta). Exige a palavra
// EXCLUIR.
//   • Colaborador, administrador ou Gestor que não é o único Gestor: apaga
//     publicações e fotos do feed, foto de perfil, a linha de usuarios e o
//     login. O que ele criou para a empresa (projetos, ensaios, fotos,
//     relatórios) fica com a empresa, sem o vínculo de autoria.
//   • Único Gestor, com outros usuários na empresa: recusa; ele precisa
//     passar a gestão para alguém antes.
//   • Único usuário da empresa: apaga a empresa inteira junto (mesma rotina
//     de "Excluir empresa").
async function deleteOwnAccount(userId: string, body: JsonRecord) {
  if ((asText(body.confirmacao) ?? '').toUpperCase() !== 'EXCLUIR') {
    return jsonResponse(400, { erro: 'Digite EXCLUIR para confirmar.' })
  }
  const admin = adminClient()
  const actor = await loadProfile(admin, userId)
  const empresaId = actor?.empresa_id ? String(actor.empresa_id) : null

  if (actor && actor.is_admin_empresa === true && empresaId) {
    if (empresaId === DIAVICON_EMPRESA_ID) {
      return jsonResponse(403, { erro: 'A conta de Gestor da DIAVICON não pode ser excluída por aqui.' })
    }
    const { count: outros, error } = await admin
      .from('usuarios')
      .select('id', { count: 'exact', head: true })
      .eq('empresa_id', empresaId)
      .neq('id', userId)
    if (error) throw error
    if ((outros ?? 0) === 0) {
      await auditar(admin, userId, 'conta.excluida_pelo_titular', 'usuarios', userId, empresaId, { junto_com_empresa: true })
      return await removeCompanyEverything(admin, empresaId)
    }
    const { count: outrosGestores, error: gestoresError } = await admin
      .from('usuarios')
      .select('id', { count: 'exact', head: true })
      .eq('empresa_id', empresaId)
      .eq('is_admin_empresa', true)
      .eq('ativo', true)
      .neq('id', userId)
    if (gestoresError) throw gestoresError
    if ((outrosGestores ?? 0) === 0) {
      return jsonResponse(409, {
        erro: 'Você é o único Gestor e há outros usuários na empresa. Passe a gestão para outra pessoa em Empresa > Colaboradores antes de excluir sua conta.',
      })
    }
  }

  // 1. Publicações do feed (antes: depois do login apagado, a autoria some).
  const { data: preparo, error: preparoError } = await admin.rpc('preparar_exclusao_conta', { p_usuario_id: userId })
  if (preparoError) throw preparoError

  await auditar(admin, userId, 'conta.excluida_pelo_titular', 'usuarios', userId, empresaId, isRecord(preparo) ? preparo : null)

  // 2. Login (mesma ordem de delete_permanently). A linha de usuarios sai em
  //    cascata com auth.users; o delete abaixo cobre bancos sem cascade.
  const { error: authError } = await admin.auth.admin.deleteUser(userId)
  if (authError && !/not.?found/i.test(authError.message ?? '')) throw authError
  await admin.from('usuarios').delete().eq('id', userId)

  // 3. Só agora as fotos pessoais vão para a fila e são apagadas.
  await admin.rpc('enfileirar_arquivos_pessoais', { p_usuario_id: userId })
  const arquivos = await esvaziarFilaDeArquivos(admin)
  return jsonResponse(200, { sucesso: true, arquivos_excluidos: arquivos })
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
    if (action === 'complete_self_registration') return await completeSelfRegistration(auth.user.id, body, auth.user)
    if (action === 'cleanup_google_orphan') return await cleanupGoogleOrphan(auth.user.id, auth.user)
    if (action === 'complete_profile') return await completeProfile(auth.user.id, body, auth.user)
    if (action === 'manage_collaborator') return await manageCollaborator(auth.user.id, body)
    if (action === 'transfer_primary_admin') return await transferPrimaryAdmin(auth.user.id, body)
    if (action === 'list_company_colleagues') return await listCompanyColleagues(auth.user.id)
    if (action === 'list_company_members_admin') return await listCompanyMembersAdmin(auth.user.id)
    if (action === 'delete_own_company') return await deleteOwnCompany(auth.user.id, body)
    if (action === 'delete_own_account') return await deleteOwnAccount(auth.user.id, body)
    if (action === 'platform_list_companies') return await platformListCompanies(auth.user.id)
    if (action === 'platform_delete_company') return await platformDeleteCompany(auth.user.id, body)
    return jsonResponse(400, { erro: 'Ação desconhecida.' })
  } catch (error) {
    return jsonResponse(errorStatus(error), { erro: errorMessage(error) })
  }
})
