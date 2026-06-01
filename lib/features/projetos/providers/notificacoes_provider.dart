import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'projetos_provider.dart'; 
// Importe o novo provider de empresas que criamos hoje:
import '../../projetos/providers/empresas_projeto_provider.dart'; 

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
      .from('projeto_convites_equipe')
      .select('''
        id,
        projeto_id,
        status,
        projeto:projetos(nome, image_url),
        remetente:usuarios!projeto_convites_equipe_criado_por_fkey(nome, sobrenome)
      ''')
      .eq('empresa_convidada_id', empresaId)
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

    // 🔥 Adicionado o .select() no final para forçar a confirmação
    final atualizacao = await _supabase
        .from('projeto_convites_equipe')
        .update({'status': 'aceito'})
        .eq('id', conviteId)
        .select();

    if (atualizacao.isEmpty) {
      throw Exception('O banco de dados bloqueou a atualização do convite.');
    }

    _ref.invalidate(notificacoesProvider); 
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId)); 
  }

  Future<void> recusarConvite(String conviteId) async {
    // 🔥 Adicionado o .select() no final para forçar a confirmação
    final atualizacao = await _supabase
        .from('projeto_convites_equipe')
        .update({'status': 'recusado'})
        .eq('id', conviteId)
        .select();

    if (atualizacao.isEmpty) {
      throw Exception('O banco de dados bloqueou a recusa do convite.');
    }

    // Invalida a tela para o card sumir
    _ref.invalidate(notificacoesProvider);
  }
}