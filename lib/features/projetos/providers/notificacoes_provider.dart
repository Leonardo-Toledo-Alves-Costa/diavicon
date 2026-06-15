import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'projetos_provider.dart'; 
import '../../projetos/providers/empresas_projeto_provider.dart'; 
// 🔥 CORREÇÃO: Import do provider da equipe para invalidar a tela quando aceitar
import '../../equipe/providers/equipe_provider.dart';

final notificacoesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return [];

  final usuarioData = await supabase
      .from('usuarios')
      .select('empresa_id')
      .eq('id', userId)
      .maybeSingle();

  final empresaId = usuarioData?['empresa_id'];
  if (empresaId == null) return [];

  final response = await supabase
      .from('projeto_empresas_colaboradoras')
      .select('''
        id,
        projeto_id,
        status,
        projeto:projetos(nome, image_url),
        remetente:usuarios!projeto_empresas_colaboradoras_criado_por_fkey(nome, sobrenome)
      ''')
      .eq('empresa_id', empresaId)
      .eq('status', 'pendente');

  return List<Map<String, dynamic>>.from(response);
});

final notificacoesControllerProvider = Provider((ref) => NotificacoesController(ref));

class NotificacoesController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  NotificacoesController(this._ref);

  Future<void> aceitarConvite({
    required String conviteId,
    required String projetoId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada.');

    final atualizacao = await _supabase
        .from('projeto_empresas_colaboradoras')
        .update({'status': 'aceito'})
        .eq('id', conviteId)
        .select();

    if (atualizacao.isEmpty) {
      throw Exception('O banco de dados bloqueou a atualização do convite.');
    }

    final jaNaEquipe = await _supabase
        .from('projeto_equipe_interna')
        .select('usuario_id')
        .eq('projeto_id', projetoId)
        .eq('usuario_id', userId)
        .maybeSingle();

    if (jaNaEquipe != null) {
      await _supabase
          .from('projeto_equipe_interna')
          .update({'ativo': true})
          .eq('projeto_id', projetoId)
          .eq('usuario_id', userId);
    } else {
      final usuarioData = await _supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
      await _supabase.from('projeto_equipe_interna').insert({
        'projeto_id': projetoId,
        'empresa_id': usuarioData?['empresa_id'],
        'usuario_id': userId,
        'ativo': true,
        // 🔥 CORREÇÃO: Faltava definir is_gestor = false para parceiros
        'is_gestor': false, 
      });
    }

    _ref.invalidate(notificacoesProvider); 
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId)); 
    // 🔥 CORREÇÃO: Invalida a equipe do projeto para atualizar a UI
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
  }

  Future<void> recusarConvite(String conviteId) async {
    final atualizacao = await _supabase
        .from('projeto_empresas_colaboradoras')
        .update({'status': 'recusado'})
        .eq('id', conviteId)
        .select();

    if (atualizacao.isEmpty) {
      throw Exception('O banco de dados bloqueou a recusa do convite.');
    }

    _ref.invalidate(notificacoesProvider);
  }
}