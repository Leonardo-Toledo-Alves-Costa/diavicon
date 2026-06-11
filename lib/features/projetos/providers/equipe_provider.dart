import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final buscarEmpresaPorCnpjProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, cnpj) async {
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

final colaboradoresProjetoProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  // 🔥 AQUI: Pedimos para o banco trazer a coluna 'ativo'
  final response = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('empresa_id, ativo, usuario:usuarios(id, nome, sobrenome, cargo, foto_url)')
      .eq('projeto_id', projetoId);
  return List<Map<String, dynamic>>.from(response);
});

final colaboradoresAtivosProjetoProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  // Ele espera o provider principal carregar e pega a lista
  final todosColaboradores = await ref.watch(colaboradoresProjetoProvider(projetoId).future);
  
  // Devolve só quem está com a caixinha marcada (ativo == true)
  return todosColaboradores.where((c) => c['ativo'] == true).toList();
});

final gestaoProjetoProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  
  final projetoData = await supabase.from('projetos').select('empresa_gestora_id').eq('id', projetoId).maybeSingle();
  if (projetoData == null) return null;

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final usuarioData = await supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();

  return {
    'empresa_gestora_id': projetoData['empresa_gestora_id'],
    'empresa_usuario_logado_id': usuarioData?['empresa_id'],
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

    // 🔥 BUSCA TAMBÉM O STATUS DE ATIVO
    final jaColaborador = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select('ativo')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaConvidadaId)
        .maybeSingle();

    // SÓ BLOQUEIA SE ELA JÁ ESTIVER ATIVA (Se for false, deixa passar o reenvio)
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

  // 🔥 AQUI: Substituímos o "removerColaborador" por este método que só atualiza o status
  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    await _supabase
        .from('projeto_empresas_colaboradoras')
        .update({'ativo': ativo})
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId);

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }

  Future<void> alterarGestor({required String projetoId, required String novaEmpresaGestoraId}) async {
    await _supabase
        .from('projetos')
        .update({'empresa_gestora_id': novaEmpresaGestoraId})
        .eq('id', projetoId);

    _ref.invalidate(gestaoProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }

  Future<void> aceitarConvite({required String conviteId, required String projetoId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada.');

    // 1. Pega o ID da empresa do usuário que está aceitando
    final usuarioData = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();

    final empresaId = usuarioData?['empresa_id'];
    if (empresaId == null) throw Exception('Usuário não vinculado a uma empresa.');

    // 2. Atualiza o status do convite
    await _supabase
        .from('projeto_convites_equipe')
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    // 3. Verifica se essa empresa já foi colaboradora no passado (Soft Delete)
    final jaColaborador = await _supabase
        .from('projeto_empresas_colaboradoras')
        .select('empresa_id')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaId)
        .maybeSingle();

    if (jaColaborador != null) {
      // Se já existe, apenas reativa
      await _supabase
          .from('projeto_empresas_colaboradoras')
          .update({'ativo': true})
          .eq('projeto_id', projetoId)
          .eq('empresa_id', empresaId);
    } else {
      // Se é a primeira vez, insere do zero
      await _supabase.from('projeto_empresas_colaboradoras').insert({
        'projeto_id': projetoId,
        'empresa_id': empresaId,
        'usuario_id': userId, // Opcional, se sua tabela exigir
        'ativo': true,
      });
    }

    // 4. Invalida os providers para a tela atualizar sozinha
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }
}