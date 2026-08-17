import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'projetos_provider.dart'; 
import '../../projetos/providers/empresas_projeto_provider.dart'; 
import '../../equipe/providers/equipe_provider.dart';

// PROVIDER PARA O BADGE DO SININHO (Em tempo real)
final contadorNaoLidasProvider = StreamProvider.autoDispose<int>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return Stream.value(0);

  return supabase
      .from('notificacoes')
      .stream(primaryKey: ['id'])
      .map((lista) {
        // Garante que campos nulos também sejam contados como "não lidos"
        return lista.where((n) => n['lida'] != true).length;
      });
});

// PROVIDER DA TELA DE NOTIFICAÇÕES (Em tempo real)
final notificacoesProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return Stream.value([]);

  return supabase
      .from('notificacoes')
      .stream(primaryKey: ['id'])
      .map((lista) {
        final listaOrdenada = List<Map<String, dynamic>>.from(lista);
        
        listaOrdenada.sort((a, b) {
          final dataA = DateTime.tryParse(a['criado_em']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dataB = DateTime.tryParse(b['criado_em']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dataB.compareTo(dataA); 
        });
        
        return listaOrdenada;
      });
});

final notificacoesControllerProvider = Provider((ref) => NotificacoesController(ref));

class NotificacoesController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  NotificacoesController(this._ref);

  // MARCAR COMO LIDA
  Future<void> marcarComoLida(String idNotificacao) async {
    await _supabase
        .from('notificacoes')
        .update({'lida': true})
        .eq('id', idNotificacao);
  }

  Future<void> aceitarConvite({
    required String conviteId,
    required String projetoId,
    required String notificacaoId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada.');

    // Aceita o convite na tabela original
    await _supabase
        .from('projeto_empresas_colaboradoras')
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    // Coloca o usuário na equipe
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
        'is_gestor': false, 
      });
    }

    //Marca a notificação como lida
    await marcarComoLida(notificacaoId);

    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(empresasVinculadasProjetoProvider(projetoId)); 
    _ref.invalidate(colaboradoresAtivosProjetoProvider(projetoId));
  }

  Future<void> recusarConvite(String conviteId, String notificacaoId) async {
    await _supabase
        .from('projeto_empresas_colaboradoras')
        .update({'status': 'recusado'})
        .eq('id', conviteId);
        
    await marcarComoLida(notificacaoId);
  }
}