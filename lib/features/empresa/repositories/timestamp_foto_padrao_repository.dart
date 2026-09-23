import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/timestamp_foto_padrao_model.dart';

final timestampFotoPadraoRepositoryProvider = Provider<TimestampFotoPadraoRepository>((ref) {
  return TimestampFotoPadraoRepository(Supabase.instance.client);
});

// Busca o padrão de legenda da empresa. Retorna null se a empresa ainda não configurou nada.
final timestampFotoPadraoProvider =
    FutureProvider.family.autoDispose<TimestampFotoPadraoModel?, String>((ref, empresaId) {
  return ref.watch(timestampFotoPadraoRepositoryProvider).buscarPadrao(empresaId);
});

class TimestampFotoPadraoRepository {
  final SupabaseClient _supabase;
  TimestampFotoPadraoRepository(this._supabase);

  static const _tabela = 'empresa_timestamp_fotos_padrao';

  Future<TimestampFotoPadraoModel?> buscarPadrao(String empresaId) async {
    try {
      final row = await _supabase
          .from(_tabela)
          .select()
          .eq('empresa_id', empresaId)
          .order('criado_em', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row == null) {
        debugPrint('[TimestampFotoPadrao] nenhum padrão salvo para empresa $empresaId');
        return null;
      }
      final padrao = TimestampFotoPadraoModel.fromMap(row, empresaId);
      debugPrint(
        '[TimestampFotoPadrao] carregado empresa=$empresaId ativo=${padrao.temAlgumCampoAtivo} '
        'projeto=${padrao.projeto} estrutura=${padrao.estrutura} conjunto=${padrao.conjuntoEstrutural} '
        'local=${padrao.local} data=${padrao.data} hora=${padrao.hora} nomeEmpresa=${padrao.nomeEmpresa} '
        'logo=${padrao.logo} nomeUser=${padrao.nomeUser} latLong=${padrao.latitudeLongitude} descricao=${padrao.descricao}',
      );
      return padrao;
    } on PostgrestException catch (e) {
      throw Exception('Erro ao buscar padrão de legenda: ${e.message}');
    }
  }

  // Não há constraint UNIQUE em empresa_id na tabela. Em vez de confiar num
  // `id` em memória (que pode estar desatualizado se outra sessão salvou
  // antes), resolve sempre a linha canônica direto no banco: se por algum
  // teste antigo sobrarem linhas duplicadas para a mesma empresa, mantém só
  // a mais recente e apaga o resto, evitando que uma linha "fantasma" (sem
  // os campos marcados) seja lida por engano depois.
  Future<TimestampFotoPadraoModel> salvarPadrao(TimestampFotoPadraoModel padrao) async {
    try {
      final existentes = await _supabase
          .from(_tabela)
          .select('id')
          .eq('empresa_id', padrao.empresaId)
          .order('criado_em', ascending: false);
      final idsExistentes = (existentes as List).map((r) => r['id'] as String).toList();

      if (idsExistentes.isEmpty) {
        final row = await _supabase.from(_tabela).insert(padrao.toMap()).select().single();
        debugPrint('[TimestampFotoPadrao] criado novo padrão para empresa ${padrao.empresaId}');
        return TimestampFotoPadraoModel.fromMap(row, padrao.empresaId);
      }

      final idCanonico = idsExistentes.first;
      if (idsExistentes.length > 1) {
        debugPrint('[TimestampFotoPadrao] ${idsExistentes.length} linhas duplicadas para empresa '
            '${padrao.empresaId}; mantendo apenas $idCanonico');
        await _supabase.from(_tabela).delete().inFilter('id', idsExistentes.sublist(1));
      }

      final row = await _supabase.from(_tabela).update(padrao.toMap()).eq('id', idCanonico).select().single();
      return TimestampFotoPadraoModel.fromMap(row, padrao.empresaId);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao salvar padrão de legenda: ${e.message}');
    }
  }
}
