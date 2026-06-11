import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =========================================================================
// ISOLAMENTO DE DADOS E LISTAGEM GERAL DA EMPRESA
// =========================================================================

// 🔥 .autoDispose adicionado para a lista atualizar sem precisar de Hot Restart
final colaboradoresProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return [];

  final usuarioLogadoData = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
  final minhaEmpresaId = usuarioLogadoData?['empresa_id'];
  if (minhaEmpresaId == null) return [];

  // 1. Busca TODOS os usuários da empresa (sem ocultar ninguém)
  final usuariosResponse = await supabase
      .from('usuarios')
      .select('id, nome, sobrenome, cargo, foto_url, titulo_principal, is_admin_empresa')
      .eq('empresa_id', minhaEmpresaId);

  // 2. Busca QUEM já tem vínculo com este projeto específico
  final equipeResponse = await supabase
      .from('projeto_equipe_interna')
      .select('usuario_id, ativo, is_gestor')
      .eq('projeto_id', projetoId);

  // Mapeia quem já está no projeto para cruzar as informações
  final equipeMap = {
    for (var row in equipeResponse) row['usuario_id']: row
  };

  return (usuariosResponse as List).map((userRow) {
    final String uId = userRow['id'];
    final link = equipeMap[uId];

    final bool isAdminGlobal = userRow['is_admin_empresa'] ?? false;
    final bool isGestorNoProjeto = link != null ? (link['is_gestor'] ?? false) : false;

    return {
      'usuario': userRow,
      'ativo': link != null ? (link['ativo'] ?? false) : false,
      // Se ele for admin global da empresa, a chave de gestor já nasce ativada visualmente!
      'is_gestor': isAdminGlobal || isGestorNoProjeto, 
      'empresa_id': minhaEmpresaId, 
    };
  }).toList();
});

final colaboradoresAtivosProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final todosColaboradores = await ref.watch(colaboradoresProjetoProvider(projetoId).future);
  return todosColaboradores.where((c) => c['ativo'] == true).toList();
});

// =========================================================================
// VALIDAÇÃO DE PERMISSÃO SUPREMA
// =========================================================================

final gestaoProjetoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  
  final projetoData = await supabase.from('projetos').select('empresa_gestora_id').eq('id', projetoId).maybeSingle();
  if (projetoData == null) return null;

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final usuarioData = await supabase.from('usuarios').select('empresa_id, is_admin_empresa').eq('id', userId).maybeSingle();

  final permissaoEquipe = await supabase
      .from('projeto_equipe_interna')
      .select('is_gestor')
      .eq('projeto_id', projetoId)
      .eq('usuario_id', userId)
      .maybeSingle();

  final bool isMinhaEmpresaDona = usuarioData?['empresa_id'] != null && usuarioData?['empresa_id'] == projetoData['empresa_gestora_id'];
  
  // A CHAVE MESTRA: Ele é o dono/fundador da empresa?
  final bool isAdminGlobal = usuarioData?['is_admin_empresa'] ?? false;

  // Ou ele tem a permissão manual concedida por outro chefe neste projeto específico?
  final bool isGestorEspecifico = permissaoEquipe?['is_gestor'] ?? false;

  return {
    'empresa_gestora_id': projetoData['empresa_gestora_id'],
    'empresa_usuario_logado_id': usuarioData?['empresa_id'],
    // Libera os botões de edição APENAS se ele for Admin da empresa gestora OU se for gestor explícito do projeto
    'is_user_gestor_equipe': (isMinhaEmpresaDona && isAdminGlobal) || isGestorEspecifico, 
  };
});