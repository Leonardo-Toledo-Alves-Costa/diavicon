import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../projetos/providers/projetos_provider.dart'; 

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

// Provider exclusivo para o contador da tela de empresas (Conta TODO MUNDO do projeto)
final contagemGeralColaboradoresProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('projeto_equipe_interna')
      .select('empresa_id')
      .eq('projeto_id', projetoId)
      .eq('ativo', true);
  return List<Map<String, dynamic>>.from(response);
});

// Lista candidatos da empresa do usuário logado para o editor da equipe.
// A autorização, o tenant e a exclusão do usuário atual são definidos no RPC.
final colaboradoresProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentUser == null) return [];

  final response = await supabase.rpc(
    'list_project_team_candidates',
    params: {'p_projeto_id': projetoId},
  );

  return (response as List).whereType<Map>().map((row) {
    final member = Map<String, dynamic>.from(row);
    final usuarioId = member['usuario_id'];
    return {
      'usuario_id': usuarioId,
      'ativo': member['ativo'] == true,
      'is_gestor': member['is_gestor'] == true,
      'membro_obrigatorio': member['membro_obrigatorio'] == true,
      'usuario': {
        'id': usuarioId,
        'nome': member['nome'],
        'sobrenome': member['sobrenome'],
        'cargo': member['cargo'],
        'foto_url': member['foto_url'],
        // The candidate RPC intentionally does not expose this field.
        'titulo_principal': '',
      },
    };
  }).toList();
});

// Leitura mínima para a visualização normal da equipe, inclusive para usuários
// que não têm permissão para abrir o editor.
final colaboradoresProjetoVisiveisProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  if (supabase.auth.currentUser == null) return [];

  final response = await supabase.rpc(
    'list_project_team_visible',
    params: {'p_projeto_id': projetoId},
  );

  return (response as List).whereType<Map>().map((row) {
    final member = Map<String, dynamic>.from(row);
    final usuarioId = member['usuario_id'];
    return {
      'usuario_id': usuarioId,
      'ativo': true,
      'is_gestor': false,
      'membro_obrigatorio': false,
      'usuario': {
        'id': usuarioId,
        'nome': member['nome'],
        'sobrenome': member['sobrenome'],
        'cargo': member['cargo'],
        'foto_url': member['foto_url'],
      },
    };
  }).toList();
});

// Mantém as fotos ativas filtradas para usar nos avatares redondos da tela.
final colaboradoresAtivosProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final todosColaboradores = await ref.watch(colaboradoresProjetoVisiveisProvider(projetoId).future);
  return todosColaboradores.where((c) => c['ativo'] == true).toList();
});

// Traz os dados completos da Gestora (Nome, foto e endereço)
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

//  Verifica se o usuário logado tem permissão para editar a equipe
final permissaoEdicaoEquipeProvider = FutureProvider.autoDispose.family<bool, String>((ref, projetoId) async {
  if (Supabase.instance.client.auth.currentUser == null) return false;
  try {
    await ref.watch(colaboradoresProjetoProvider(projetoId).future);
    return true;
  } on Exception {
    return false;
  }
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

  /// Liga ou desliga a participação de um funcionário no projeto.
  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    await _supabase.rpc(
      'set_project_member_status',
      params: {
        'p_projeto_id': projetoId,
        'p_usuario_id': usuarioId,
        'p_ativo': ativo,
      },
    );

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));       
    _ref.invalidate(colaboradoresProjetoVisiveisProvider(projetoId));
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId)); 
    _ref.invalidate(contagemGeralColaboradoresProvider(projetoId)); 
    
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(projectDetailProvider(projetoId));
  }

  /// Define se um funcionário da sua equipe pode ou não ser "gestor"
  Future<void> alterarGestorEquipe({
    required String projetoId, 
    required String usuarioId, 
    required bool isGestor, 
  }) async {
    await _supabase.rpc(
      'set_project_member_manager',
      params: {
        'p_projeto_id': projetoId,
        'p_usuario_id': usuarioId,
        'p_is_gestor': isGestor,
      },
    );

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
    _ref.invalidate(gestaoProjetoProvider(projetoId)); 
    
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(projectDetailProvider(projetoId));
  }
}

// ==========================================
// PROVIDER DE VALIDAÇÃO DE PLANO (QTD USERS)
// ==========================================
typedef PlanLimitInfo = ({int cadastrados, int permitidos});

final planLimitByProjectProvider = FutureProvider.autoDispose.family<PlanLimitInfo, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return (cadastrados: 0, permitidos: 0);

  try {
    // 1. Descobre a empresa do usuário logado e as regras do plano dela
    final userResp = await supabase
        .from('usuarios')
        .select('empresa_id, empresas(planos(qtd_user))')
        .eq('id', userId)
        .maybeSingle();

    final empresaId = userResp?['empresa_id'];
    
    int permitidos = 0;
    final empresasData = userResp?['empresas'];
    if (empresasData != null && empresasData is Map) {
        final planosData = empresasData['planos'];
        if (planosData != null && planosData is Map) {
            permitidos = (planosData['qtd_user'] as num?)?.toInt() ?? 0;
        }
    }

    if (empresaId == null) {
      return (cadastrados: 0, permitidos: permitidos);
    }

    // 2. Conta todos os perfis vinculados à empresa, inclusive convites inativos
    final countRes = await supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', empresaId);

    final cadastrados = (countRes as List).length;

    return (cadastrados: cadastrados, permitidos: permitidos);
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar limite do plano: ${e.message}');
  }
});
