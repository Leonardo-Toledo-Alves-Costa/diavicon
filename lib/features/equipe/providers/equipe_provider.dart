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

//  Busca a equipe interna SÓ da empresa do usuário logado
final colaboradoresProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  // Descobre qual é a empresa do usuário logado
  final userResp = await supabase.from('usuarios').select('empresa_id').eq('id', userId).single();
  final minhaEmpresaId = userResp['empresa_id'];

  // Busca TODOS os funcionários cadastrados na SUA empresa
  final funcionarios = await supabase
      .from('usuarios')
      .select('id, nome, sobrenome, cargo, foto_url, is_admin_empresa')
      .eq('empresa_id', minhaEmpresaId)
      .eq('ativo', true);

  // Busca quem tem registro na equipe interna DESTE projeto (Só da sua empresa)
  final equipeProjeto = await supabase
      .from('projeto_equipe_interna')
      .select('usuario_id, ativo, is_gestor')
      .eq('projeto_id', projetoId)
      .eq('empresa_id', minhaEmpresaId); 

  final mapaEquipe = {
    for (var e in equipeProjeto) e['usuario_id']: e
  };

  // Cruza as informações e aplica a "Regra do Admin"
  return funcionarios.map((func) {
    final fId = func['id'];
    final inEquipe = mapaEquipe[fId];
    
    final bool isAdmin = func['is_admin_empresa'] == true;
    
    //  Admin sempre faz parte da equipe da SUA empresa. Senão, puxa do banco (ou falso)
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

// Mantém as fotos ativas filtradas para usar nos avatares redondos da tela
final colaboradoresAtivosProjetoProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final todosColaboradores = await ref.watch(colaboradoresProjetoProvider(projetoId).future);
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
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final userResp = await supabase.from('usuarios').select('is_admin_empresa').eq('id', userId).single();
  if (userResp['is_admin_empresa'] == true) return true;

  final equipeResp = await supabase
      .from('projeto_equipe_interna')
      .select('is_gestor')
      .eq('projeto_id', projetoId)
      .eq('usuario_id', userId)
      .maybeSingle();

  return equipeResp?['is_gestor'] == true;
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
    // Checa se o usuário é Admin antes de tentar desligar ele
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
    
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(projectDetailProvider(projetoId));
  }

  /// Define se um funcionário da sua equipe pode ou não ser "gestor"
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

    // 2. Conta todos os colaboradores ativos vinculados à sua empresa
    final countRes = await supabase
        .from('usuarios')
        .select('id')
        .eq('empresa_id', empresaId)
        .eq('ativo', true);

    final cadastrados = (countRes as List).length;

    return (cadastrados: cadastrados, permitidos: permitidos);
  } on PostgrestException catch (e) {
    throw Exception('Erro ao buscar limite do plano: ${e.message}');
  }
});