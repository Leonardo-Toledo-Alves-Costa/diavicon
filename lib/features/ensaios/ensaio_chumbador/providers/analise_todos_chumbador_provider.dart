import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chumbador_model.dart';

typedef AnaliseChumbadorParams = ({String projetoId, String estruturaId});

class PontoChumbadorResumoModel {
  final String pontoGeralId;
  final String nomePonto;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final double? cargaMaxima;
  final double? deslocamentoMaximo;
  final CondicaoAvaliacaoChumbador? condicaoAvaliacao;

  const PontoChumbadorResumoModel({
    required this.pontoGeralId,
    required this.nomePonto,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.cargaMaxima,
    required this.deslocamentoMaximo,
    required this.condicaoAvaliacao,
  });
}

// Mesmo padrão de `analiseTodosMonitoramentoFissuraProvider` — busca todos
// os pontos de Tração em Chumbador da estrutura, com carga máxima/
// deslocamento máximo/condição de avaliação já calculados e salvos no
// registro do ensaio (não precisa buscar as leituras aqui).
final analiseTodosChumbadorProvider =
    FutureProvider.family.autoDispose<List<PontoChumbadorResumoModel>, AnaliseChumbadorParams>((ref, params) async {
  final supabase = Supabase.instance.client;

  final resp = await supabase
      .from('pontos_ensaios_geral')
      .select('''
        id, nome_ponto,
        elementos_estruturais!inner(nome, tipo, local, estrutura_id),
        ponto_ensaio_tracao(carga_max, desloc_max, cond_avaliar)
      ''')
      .eq('projeto_id', params.projetoId)
      .eq('elementos_estruturais.estrutura_id', params.estruturaId)
      .ilike('tipo_ensaio', '%chumbad%');

  final resultado = <PontoChumbadorResumoModel>[];
  for (final p in (resp as List)) {
    final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
    final ensaioList = p['ponto_ensaio_tracao'] as List? ?? const [];
    if (ensaioList.isEmpty) continue;
    final ensaio = (ensaioList.first as Map).cast<String, dynamic>();

    resultado.add(PontoChumbadorResumoModel(
      pontoGeralId: p['id'].toString(),
      nomePonto: p['nome_ponto']?.toString() ?? 'Ponto',
      nomeElemento: elemento?['nome']?.toString() ?? '',
      tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
      local: elemento?['local']?.toString() ?? 'Desconhecido',
      cargaMaxima: double.tryParse(ensaio['carga_max']?.toString() ?? ''),
      deslocamentoMaximo: double.tryParse(ensaio['desloc_max']?.toString() ?? ''),
      condicaoAvaliacao: CondicaoAvaliacaoChumbador.fromChave(ensaio['cond_avaliar']?.toString()),
    ));
  }

  return resultado;
});
