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

// 🔥 ATUALIZADO: Agora busca da tabela correta de equipe interna (funcionários)
final colaboradoresProjetoProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('projeto_equipe_interna')
      .select('empresa_id, ativo, usuario:usuarios(id, nome, sobrenome, cargo, foto_url, titulo_principal)')
      .eq('projeto_id', projetoId);
  return List<Map<String, dynamic>>.from(response);
});

final colaboradoresAtivosProjetoProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, projetoId) async {
  final todosColaboradores = await ref.watch(colaboradoresProjetoProvider(projetoId).future);
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

  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    await _supabase
        .from('projeto_equipe_interna')
        .update({'ativo': ativo})
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId);

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }

  // 🔥 ADICIONE NO SEU EquipeController (em equipe_provider.dart)
  Future<void> alterarGestorEquipe({
    required String projetoId, 
    required String usuarioId, 
    required bool isGestor, // true para virar gestor, false para voltar a colaborador normal
  }) async {
    
    // Atualiza apenas o nível de acesso da pessoa na equipe interna
    await _supabase
        .from('projeto_equipe_interna')
        .update({'is_gestor': isGestor}) // ⚠️ Lembre de criar essa coluna no banco!
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId);

    // Invalida a lista de equipe para a UI reagir
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }
}