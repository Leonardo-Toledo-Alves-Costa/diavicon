import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final buscarEmpresaPorCnpjProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, cnpj) async {
  if (cnpj.isEmpty) return null;
  final supabase = Supabase.instance.client;
  try {
    final response = await supabase
        .from('empresas')
        .select('id, nome, cnpj, foto_url')
        .eq('cnpj', cnpj)
        .maybeSingle();
    return response;
  } catch (e) {
    return null;
  }
});

// 🔥 LIMPEZA AUTOMÁTICA ATIVADA (.autoDispose)
final contagemGeralColaboradoresProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('projeto_equipe_interna')
      .select('empresa_id')
      .eq('projeto_id', projetoId)
      .eq('ativo', true);
  return List<Map<String, dynamic>>.from(response);
});

// 🔥 LIMPEZA AUTOMÁTICA ATIVADA (.autoDispose)
final colaboradoresProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final userResp = await supabase.from('usuarios').select('empresa_id').eq('id', userId).single();
  final minhaEmpresaId = userResp['empresa_id'];

  final funcionarios = await supabase
      .from('usuarios')
      .select('id, nome, sobrenome, cargo, foto_url, is_admin_empresa')
      .eq('empresa_id', minhaEmpresaId)
      .eq('ativo', true);

  final equipeProjeto = await supabase
      .from('projeto_equipe_interna')
      .select('usuario_id, ativo, is_gestor')
      .eq('projeto_id', projetoId)
      .eq('empresa_id', minhaEmpresaId); 

  final mapaEquipe = {
    for (var e in equipeProjeto) e['usuario_id']: e
  };

  return funcionarios.map((func) {
    final fId = func['id'];
    final inEquipe = mapaEquipe[fId];
    
    final bool isAdmin = func['is_admin_empresa'] == true;
    
    final bool isAtivo = isAdmin ? true : (inEquipe?['ativo'] ?? false);
    final bool isGestor = isAdmin ? true : (inEquipe?['is_gestor'] ?? false);

    return {
      'usuario_id': fId,
      'empresa_id': minhaEmpresaId,
      'ativo': isAtivo,
      'is_gestor': isGestor,
      'is_admin_empresa': isAdmin, 
      'usuario': func,
    };
  }).toList();
});

// 🔥 LIMPEZA AUTOMÁTICA ATIVADA (.autoDispose)
final colaboradoresAtivosProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final todosColaboradores = await ref.watch(colaboradoresProjetoProvider(projetoId).future);
  return todosColaboradores.where((c) => c['ativo'] == true).toList();
});

// 🔥 NOVO PROVIDER: Verifica se o usuário logado tem permissão para editar a equipe
final permissaoEdicaoEquipeProvider = FutureProvider.autoDispose.family<bool, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  // 1. Checa se ele é o Admin da empresa (Tem poder supremo)
  final userResp = await supabase.from('usuarios').select('is_admin_empresa').eq('id', userId).single();
  if (userResp['is_admin_empresa'] == true) return true;

  // 2. Se não for admin, checa se ele recebeu permissão de "is_gestor" neste projeto específico
  final equipeResp = await supabase
      .from('projeto_equipe_interna')
      .select('is_gestor')
      .eq('projeto_id', projetoId)
      .eq('usuario_id', userId)
      .maybeSingle();

  return equipeResp?['is_gestor'] == true;
});

// 🔥 LIMPEZA AUTOMÁTICA ATIVADA (.autoDispose)
final gestaoProjetoProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  
  final projetoData = await supabase
      .from('projetos')
      .select('empresa_gestora_id, empresas!projetos_empresa_gestora_id_fkey(id, nome, foto_url, enderecos(cidade, estado))')
      .eq('id', projetoId)
      .maybeSingle();

  if (projetoData == null) return null;

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final usuarioData = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();

  return {
    'empresa_gestora_id': projetoData['empresa_gestora_id'],
    'empresa_usuario_logado_id': usuarioData?['empresa_id'],
    'empresas': projetoData['empresas'], 
  };
});

final equipeControllerProvider = Provider((ref) => EquipeController(ref));

class EquipeController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  EquipeController(this._ref);

  Future<void> enviarConvite({required String projetoId, required String empresaConvidadaId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    final jaColaborador = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select('ativo')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaConvidadaId)
        .maybeSingle();

    if (jaColaborador != null && jaColaborador['ativo'] == true) {
      throw Exception('Esta empresa já é colaboradora ativa do projeto.');
    }

    final convitePendente = await _supabase
        .from('projeto_convites_equipe')
        .select('id')
        .eq('projeto_id', projetoId)
        .eq('empresa_convidada_id', empresaConvidadaId)
        .eq('status', 'pendente')
        .maybeSingle();

    if (convitePendente != null) throw Exception('Um convite pendente já foi enviado para esta empresa.');

    await _supabase.from('projeto_convites_equipe').insert({
      'projeto_id': projetoId,
      'empresa_convidada_id': empresaConvidadaId,
      'criado_por': userId,
      'status': 'pendente'
    });
  }

  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    final userData = await _supabase.from('usuarios').select('empresa_id, is_admin_empresa').eq('id', usuarioId).single();
    if (userData['is_admin_empresa'] == true && !ativo) {
      throw Exception('Administradores da empresa não podem ser removidos do projeto.');
    }

    final existe = await _supabase
        .from('projeto_equipe_interna')
        .select('projeto_id') 
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (existe != null) {
      await _supabase
          .from('projeto_equipe_interna')
          .update({'ativo': ativo})
          .eq('projeto_id', projetoId)
          .eq('usuario_id', usuarioId);
    } else {
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'usuario_id': usuarioId,
        'empresa_id': userData['empresa_id'],
        'ativo': ativo,
        'is_gestor': false, 
      });
    }

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));       
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId)); 
    _ref.invalidate(contagemGeralColaboradoresProvider(projetoId)); 
  }

  Future<void> alterarGestorEquipe({
    required String projetoId, 
    required String usuarioId, 
    required bool isGestor, 
  }) async {
    await _supabase
        .from('projeto_equipe_interna')
        .update({'is_gestor': isGestor}) 
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId);

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
    _ref.invalidate(gestaoProjetoProvider(projetoId)); 
  }
}