import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monitoramento_fissura_model.dart';

typedef AnaliseFissuraParams = ({String projetoId, String estruturaId});

class PontoMonitoramentoResumoModel {
  final String pontoGeralId;
  final String nomePonto;
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final TipoSeloFissura tipoSelo;
  final StatusFissura status;
  final DateTime? dataUltimaLeitura;
  final double? deltaMaxUltima;
  // Ordenadas por data — usadas pro mini-gráfico de movimento (X,Y) no card
  // da análise geral.
  final List<MedicaoFissuraModel> medicoes;

  const PontoMonitoramentoResumoModel({
    required this.pontoGeralId,
    required this.nomePonto,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.tipoSelo,
    required this.status,
    required this.dataUltimaLeitura,
    required this.deltaMaxUltima,
    required this.medicoes,
  });

  // Foto da medição mais recente — usada no lugar do mini-gráfico quando o
  // status é Rompido (mais informativo ver a foto do rompimento do que um
  // gráfico abstrato).
  String? get fotoUltimaMedicao => medicoes.isEmpty ? null : medicoes.last.foto;
}

// Mesmo padrão de `analiseTodosPotencialProvider`/`analiseTodosUltrassomProvider`
// — busca todos os pontos de Monitoramento de Fissuras da estrutura, com a
// instalação e as leituras (só precisa das 2 últimas pra calcular a
// variação mais recente, mas vem tudo já que o volume por ponto é baixo).
final analiseTodosMonitoramentoFissuraProvider =
    FutureProvider.family.autoDispose<List<PontoMonitoramentoResumoModel>, AnaliseFissuraParams>((ref, params) async {
  final supabase = Supabase.instance.client;

  final resp = await supabase
      .from('pontos_ensaios_geral')
      .select('''
        id, nome_ponto,
        elementos_estruturais!inner(nome, tipo, local, estrutura_id),
        ponto_ensaio_monitoramento_fissura(
          selo,
          ponto_ensaio_monitoramento_fissura_leitura(data, hora, medida_x, medida_y, status, foto)
        )
      ''')
      .eq('projeto_id', params.projetoId)
      .eq('elementos_estruturais.estrutura_id', params.estruturaId)
      .ilike('tipo_ensaio', '%monitoramento%fissura%');

  final resultado = <PontoMonitoramentoResumoModel>[];
  for (final p in (resp as List)) {
    final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
    final instalacaoList = p['ponto_ensaio_monitoramento_fissura'] as List? ?? const [];
    if (instalacaoList.isEmpty) continue;
    final instalacao = (instalacaoList.first as Map).cast<String, dynamic>();

    final leiturasJson = instalacao['ponto_ensaio_monitoramento_fissura_leitura'] as List? ?? const [];
    final medicoes = leiturasJson.map((l) => MedicaoFissuraModel.fromJson((l as Map).cast<String, dynamic>())).toList()
      ..sort((a, b) => (a.dataHora ?? DateTime(0)).compareTo(b.dataHora ?? DateTime(0)));

    final ultima = medicoes.isEmpty ? null : medicoes.last;
    final penultima = medicoes.length > 1 ? medicoes[medicoes.length - 2] : null;
    final deltaMax = ultima == null
        ? null
        : [
            (ultima.medidaX - (penultima?.medidaX ?? 0)).abs(),
            (ultima.medidaY - (penultima?.medidaY ?? 0)).abs(),
          ].reduce((a, b) => a > b ? a : b);

    resultado.add(PontoMonitoramentoResumoModel(
      pontoGeralId: p['id'].toString(),
      nomePonto: p['nome_ponto']?.toString() ?? 'Ponto',
      nomeElemento: elemento?['nome']?.toString() ?? '',
      tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
      local: elemento?['local']?.toString() ?? 'Desconhecido',
      tipoSelo: TipoSeloFissura.fromChave(instalacao['selo']?.toString()),
      status: ultima?.status ?? StatusFissura.estavel,
      dataUltimaLeitura: ultima?.dataHora,
      deltaMaxUltima: deltaMax,
      medicoes: medicoes,
    ));
  }

  return resultado;
});
