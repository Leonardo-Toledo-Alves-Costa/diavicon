import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🔥 Ajuste este caminho de acordo com a estrutura real das suas pastas!
import '../providers/equipe_provider.dart';

// Provider que expõe o Controller para a UI
final equipeControllerProvider = Provider((ref) => EquipeController(ref));

class EquipeController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  EquipeController(this._ref);

  /// Liga ou desliga a participação de um funcionário no projeto.
  /// Se for a primeira vez que ele é marcado, insere no banco. Se já existir, atualiza.
  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    await _supabase
        .from('projeto_equipe_interna') // 🔥 CORREÇÃO: Atualizando a tabela certa
        .update({'ativo': ativo})
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId);

    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
  }

  /// Define se um funcionário da sua equipe pode ou não ser "gestor" (adicionar/remover outros)
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

    // 🔥 Invalidando a árvore toda para refletir o novo nível de permissão
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
    _ref.invalidate(gestaoProjetoProvider(projetoId)); 
  }
}