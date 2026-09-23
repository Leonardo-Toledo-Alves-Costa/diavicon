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

