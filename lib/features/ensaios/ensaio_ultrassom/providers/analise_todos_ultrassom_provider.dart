import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_ultrassom_global_model.dart';

typedef AnaliseUltrassomParams = ({String projetoId, String estruturaId});

// Mesmo padrão de `analiseTodosPotencialProvider`, mas com 3 níveis de
// aninhamento a mais (Direto/Indireto/Mapeamento) porque Ultrassonografia
// divide seus dados em 3 sub-tabelas por modo, diferente de Potencial que
// usa só uma.
final analiseTodosUltrassomProvider =
    FutureProvider.family.autoDispose<List<PontoAnaliseUltrassomModel>, AnaliseUltrassomParams>((ref, params) async {
  try {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('pontos_ensaios_geral')
        .select('''
          id,
          nome_ponto,
          elemento_estrutural_id,
          elementos_estruturais!inner (
            nome,
            tipo,
            local,
            estrutura_id,
            estruturas_locais (
              nome
            )
          ),
          ponto_ensaio_ultrassom (
            id,
            modo,
            tipo_onda,
            alfa_e,
            densidade,
            ponto_ensaio_ultrassom_direto_medicao (
              ponto_ensaio_ultrassom_direto_leitura ( velocidade )
            ),
            ponto_ensaio_ultrassom_indireto_medicao (
              ponto_ensaio_ultrassom_indireto_leitura ( distancia, velocidade )
            ),
            ponto_ensaio_ultrassom_mapeamento (
              ponto_ensaio_ultrassom_mapeamento_leitura ( linha, coluna, velocidade )
            )
          )
        ''')
        .eq('projeto_id', params.projetoId)
        .eq('elementos_estruturais.estrutura_id', params.estruturaId)
        // 'ultrassonografia' tem 2 "s" seguidos ('ultra-ss-onografia') — um
        // padrão com 1 só ('ultrason') nunca bate; 'ultrass' cobre tanto
        // esse nome quanto qualquer variação 'Ultrassom' (mesmo cuidado já
        // documentado em ensaios_routes_map.dart/novo_ponto_ensaio_modal.dart).
        .ilike('tipo_ensaio', '%ultrass%');

    final data = response as List;
    if (data.isEmpty) return [];

    return data.expand((e) => PontoAnaliseUltrassomModel.fromMap((e as Map).cast<String, dynamic>())).toList();
  } on PostgrestException catch (e) {
    throw Exception('Erro SQL no Supabase: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado: $e');
  }
});

final analiseUltrassomRepositoryProvider = Provider<AnaliseUltrassomRepository>((ref) {
  return AnaliseUltrassomRepository(Supabase.instance.client);
});

class AnaliseUltrassomRepository {
  final SupabaseClient _supabase;
  AnaliseUltrassomRepository(this._supabase);

  // Atualiza αE/densidade em TODAS as linhas `ponto_ensaio_ultrassom` (todos
  // os modos/pontos) daquele elemento estrutural — os 2 campos vivem nessa
  // tabela por ponto, mas a edição na tela de análise é feita a nível de
  // elemento, então precisa propagar pra todos os pontos dele.
  Future<void> atualizarAlfaEDensidade({
    required String elementoId,
    required double alfaE,
    required double densidade,
  }) async {
    final pontos = await _supabase.from('pontos_ensaios_geral').select('id').eq('elemento_estrutural_id', elementoId);
    final idsPontos = (pontos as List).map((p) => p['id'].toString()).toList();
    if (idsPontos.isEmpty) return;

    await _supabase
        .from('ponto_ensaio_ultrassom')
        .update({'alfa_e': alfaE, 'densidade': densidade}).inFilter('ponto_ensaio_id', idsPontos);
  }
}
