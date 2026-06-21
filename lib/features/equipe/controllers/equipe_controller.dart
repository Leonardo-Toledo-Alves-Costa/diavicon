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
    
    // Verifica se já existe um registro na tabela de ligação para este usuário neste projeto
    final existe = await _supabase
        .from('projeto_equipe_interna')
        // 🔥 CORREÇÃO: Buscando 'projeto_id' em vez de 'id', porque a coluna 'id' não existe!
        .select('projeto_id') 
        .eq('projeto_id', projetoId)
        .eq('usuario_id', usuarioId)
        .maybeSingle();

    if (existe != null) {
      // Já foi vinculado antes, apenas atualiza o status de ativo
      await _supabase
          .from('projeto_equipe_interna')
          .update({'ativo': ativo})
          .eq('projeto_id', projetoId)
          .eq('usuario_id', usuarioId);
    } else {
      // Primeira vez que marcam ele: busca a empresa do cara e faz o insert
      final userData = await _supabase
          .from('usuarios')
          .select('empresa_id')
          .eq('id', usuarioId)
          .single();
      
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'usuario_id': usuarioId,
        'empresa_id': userData['empresa_id'],
        'ativo': ativo,
        'is_gestor': false, // Todo novo membro inserido manualmente nasce como membro comum
      });
    }

    // 🔥 Invalidando os providers para a tela atualizar no mesmo instante
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));       // Atualiza a lista de checkboxes
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId)); // Atualiza as fotinhas
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