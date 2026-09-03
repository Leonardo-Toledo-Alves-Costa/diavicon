import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/equipe_provider.dart';

// Provider que expõe o Controller para a UI
final equipeControllerProvider = Provider((ref) => EquipeController(ref));

class EquipeController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  EquipeController(this._ref);

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
  }

  /// Define se um funcionário da sua equipe pode ou não ser "gestor" (adicionar/remover outros)
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
    _ref.invalidate(colaboradoresProjetoVisiveisProvider(projetoId));
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
    _ref.invalidate(gestaoProjetoProvider(projetoId)); 
  }
}
