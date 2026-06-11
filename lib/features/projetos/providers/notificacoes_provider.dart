import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'projetos_provider.dart'; 
import 'equipe_provider.dart'; 

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

    final usuarioData = await _supabase.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
    final empresaId = usuarioData?['empresa_id'];
    if (empresaId == null) throw Exception('Usuário não está vinculado a nenhuma empresa.');

    // Muda o status do convite
    await _supabase.from('projeto_convites_equipe').update({'status': 'aceito'}).eq('id', conviteId);

    // 🔥 VERIFICA SE A EMPRESA JÁ EXISTE NO HISTÓRICO (Soft Delete)
    final jaExiste = await _supabase.from('projeto_empresas_colaboradoras')
        .select('usuario_id')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaId)
        .maybeSingle();

    if (jaExiste != null) {
      // Se ela já estava lá desmarcada, apenas reativa
      await _supabase.from('projeto_empresas_colaboradoras')
          .update({'ativo': true, 'usuario_id': userId}) 
          .eq('projeto_id', projetoId)
          .eq('empresa_id', empresaId);
    } else {
      // Se é a primeira vez na vida, insere do zero já como ATIVO
      await _supabase.from('projeto_empresas_colaboradoras').insert({
        'projeto_id': projetoId,
        'usuario_id': userId,
        'empresa_id': empresaId,
        'ativo': true, 
      });
    }

    _ref.invalidate(notificacoesProvider);
    _ref.invalidate(filteredProjectsProvider); 
    _ref.invalidate(colaboradoresProjetoProvider(projetoId)); 
  }

  Future<void> recusarConvite(String conviteId) async {
    await _supabase
        .from('projeto_convites_equipe')
        .update({'status': 'recusado'})
        .eq('id', conviteId);

    _ref.invalidate(notificacoesProvider);
  }
}