import 'package:diavicon/features/equipe/providers/equipe_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/features/projetos/providers/projetos_provider.dart'; // 🔥 IMPORT NECESSÁRIO

final equipeControllerProvider = Provider((ref) => EquipeController(ref));

class EquipeController {
  final Ref _ref;
  final _supabase = Supabase.instance.client;

  EquipeController(this._ref);

  Future<void> enviarConvite({required String projetoId, required String empresaConvidadaId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Sessão expirada. Faça login novamente.');

    final jaColaborador = await _supabase
        .from('projeto_colaboradores')
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

  Future<void> atualizarStatusColaborador({
    required String projetoId, 
    required String usuarioId, 
    required bool ativo,
  }) async {
    await _supabase
        .from('projeto_colaboradores')
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

    final usuarioData = await _supabase
        .from('usuarios')
        .select('empresa_id')
        .eq('id', userId)
        .maybeSingle();

    final empresaId = usuarioData?['empresa_id'];
    if (empresaId == null) throw Exception('Usuário não vinculado a uma empresa.');

    await _supabase
        .from('projeto_convites_equipe')
        .update({'status': 'aceito'})
        .eq('id', conviteId);

    final jaColaborador = await _supabase
        .from('projeto_colaboradores')
        .select('empresa_id')
        .eq('projeto_id', projetoId)
        .eq('empresa_id', empresaId)
        .maybeSingle();

    if (jaColaborador != null) {
      await _supabase
          .from('projeto_colaboradores')
          .update({'ativo': true})
          .eq('projeto_id', projetoId)
          .eq('empresa_id', empresaId);
    } else {
      await _supabase.from('projeto_colaboradores').insert({
        'projeto_id': projetoId,
        'empresa_id': empresaId,
        'usuario_id': userId,
        'ativo': true,
      });
    }

    // 🔥 A MÁGICA: Invalida os dois providers!
    // 1. Atualiza a tela de detalhes do projeto
    _ref.invalidate(colaboradoresProjetoProvider(projetoId));
    
    // 2. Atualiza a lista da tela ProjetosScreen para mostrar o novo projeto
    _ref.invalidate(filteredProjectsProvider); 
  }
}