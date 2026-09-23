import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/bi_data_point.dart';
import '../models/dashboard_card_model.dart';
import '../models/serie_bi_model.dart';
import '../repositories/dashboard_bi_repository.dart';
import '../utils/formato_bi.dart';
import '../utils/segmentacao_bi.dart';
import 'bi_tema.dart';

class _Ponto {
  final String categoria;
  final double? valor;
  const _Ponto(this.categoria, this.valor);
}

/// Paleta dos segmentos categóricos (tipo, local, categoria). Classes usam
/// as cores da própria escala.
final _paletaSegmentos = paletaBi;

/// Gráfico com várias séries, cada uma com tipo (barra, barra empilhada,
/// barra segmentada ou linha), eixo (esquerdo ou direito) e cor próprios.
///
/// O eixo X é compartilhado: os grupos de [DashboardCardModel.agruparPor]
/// (elemento, local, tipo ou estrutura) da união de todas as séries. Uma série
/// sem valor num grupo fica em branco ali (sem barra, linha interrompida) —
/// não vira zero, que seria uma medição que não existe.
class BiGraficoPersonalizado extends StatelessWidget {
  const BiGraficoPersonalizado({super.key, required this.card, required this.series});

  final DashboardCardModel card;

  /// id da série -> pontos buscados.
  final Map<String, List<BiDataPoint>> series;

  static const _eixo2 = 'secundario';

  @override
  Widget build(BuildContext context) {
    final agruparPor = card.agruparPor ?? 'elemento';
    final repo = DashboardBiRepository();

    final simples = <String, Map<String, double>>{};
    final segmentadas = <String, BarraSegmentadaBi>{};
    for (final s in card.series) {
      final pontos = series[s.id] ?? const <BiDataPoint>[];
      final agregacao = DashboardBiRepository.agregacaoDe(s.valor);
      if (s.tipo == TipoSerieBi.barraSegmentada && s.segmentarPor != null) {
        segmentadas[s.id] = segmentarSerieBi(pontos: pontos, agruparPor: agruparPor, segmentarPor: s.segmentarPor!, agregacao: agregacao);
      } else {
        simples[s.id] = repo.agruparValores(pontos, agruparPor, agregacao: agregacao);
      }
    }

    final categorias = {
      ...simples.values.expand((m) => m.keys),
      ...segmentadas.values.expand((b) => b.valores.values.expand((m) => m.keys)),
    }.toList()
      ..sort(compararRotulosBi);

    if (card.series.isEmpty || categorias.isEmpty) {
      return const VazioBi();
    }

    final temEixo2 = card.series.any((s) => s.eixo == 2);

    // Barras primeiro, linhas por cima — senão uma barra alta esconde a
    // linha que passa atrás dela.
    final ordenadas = [...card.series]..sort((a, b) => (a.tipo == TipoSerieBi.linha ? 1 : 0).compareTo(b.tipo == TipoSerieBi.linha ? 1 : 0));

    final variasSeries = card.series.length > 1;

    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      plotAreaBorderWidth: 0,
      legend: legendaBi(posicao: LegendPosition.bottom),
      tooltipBehavior: dicaBi(formato: 'series.name — point.x: point.y'),
      primaryXAxis: eixoCategoriaBi(rotacao: categorias.length > 6 ? 45 : 0),
      primaryYAxis: eixoNumericoBi(titulo: _tituloEixo(1, segmentadas)),
      axes: [
        if (temEixo2) eixoNumericoBi(nome: _eixo2, oposto: true, titulo: _tituloEixo(2, segmentadas)),
      ],
      series: [
        for (final s in ordenadas)
          if (segmentadas.containsKey(s.id))
            ..._pedacos(s, segmentadas[s.id]!, categorias, prefixar: variasSeries)
          else
            _serie(s, [for (final c in categorias) _Ponto(c, simples[s.id]?[c])]),
      ],
    );
  }

  /// Unidades das séries do eixo, quando todas concordam. Com unidades
  /// misturadas o título seria enganoso — fica sem.
  String? _tituloEixo(int eixo, Map<String, BarraSegmentadaBi> segmentadas) {
    final unidades = card.series
        .where((s) => s.eixo == eixo)
        .map((s) => segmentadas[s.id]?.unidade ?? s.valor.unidade)
        .toSet();
    final texto = unidades.length == 1 ? (unidades.first ?? '') : '';
    return texto.isEmpty ? null : texto;
  }

  String _nome(SerieBi s) => s.nome.isEmpty ? s.valor.rotuloPadrao() : s.nome;

  /// Uma série segmentada vira uma pilha própria: um StackedColumn por
  /// segmento, todos no mesmo grupo (não se misturam com outras pilhas).
  List<CartesianSeries<_Ponto, String>> _pedacos(SerieBi s, BarraSegmentadaBi barra, List<String> categorias, {required bool prefixar}) {
    return [
      for (var i = 0; i < barra.segmentos.length; i++)
        StackedColumnSeries<_Ponto, String>(
          name: prefixar ? '${_nome(s)} · ${barra.segmentos[i]}' : barra.segmentos[i],
          dataSource: [for (final c in categorias) _Ponto(c, barra.valores[barra.segmentos[i]]?[c])],
          xValueMapper: (p, _) => p.categoria,
          yValueMapper: (p, _) => p.valor,
          color: barra.cores[barra.segmentos[i]] ?? _paletaSegmentos[i % _paletaSegmentos.length],
          yAxisName: s.eixo == 2 ? _eixo2 : null,
          groupName: 'seg_${s.id}',
        ),
    ];
  }

  CartesianSeries<_Ponto, String> _serie(SerieBi s, List<_Ponto> dados) {
    final eixo = s.eixo == 2 ? _eixo2 : null;
    final nome = _nome(s);
    String x(_Ponto p, int _) => p.categoria;
    double? y(_Ponto p, int _) => p.valor;

    switch (s.tipo) {
      case TipoSerieBi.linha:
        return LineSeries<_Ponto, String>(
          name: nome,
          dataSource: dados,
          xValueMapper: x,
          yValueMapper: y,
          color: s.corCor,
          yAxisName: eixo,
          width: 2.5,
          markerSettings: MarkerSettings(isVisible: true, height: 6, width: 6, color: Colors.white, borderColor: s.corCor, borderWidth: 2),
        );
      case TipoSerieBi.barraEmpilhada:
        return StackedColumnSeries<_Ponto, String>(
          name: nome,
          dataSource: dados,
          xValueMapper: x,
          yValueMapper: y,
          color: s.corCor,
          yAxisName: eixo,
          // Empilha só com as séries do MESMO eixo: somar grandezas de eixos
          // diferentes numa pilha só não tem significado.
          groupName: 'eixo${s.eixo}',
        );
      // Segmentada sem "segmentar por" definido cai aqui como barra simples.
      case TipoSerieBi.barraSegmentada:
      case TipoSerieBi.barra:
        return ColumnSeries<_Ponto, String>(
          name: nome,
          dataSource: dados,
          xValueMapper: x,
          yValueMapper: y,
          color: s.corCor,
          yAxisName: eixo,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        );
    }
  }
}
