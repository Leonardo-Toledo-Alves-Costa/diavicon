import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/dashboard_card_model.dart';
import '../repositories/dashboard_bi_repository.dart';
import '../utils/formato_bi.dart';
import 'bi_tema.dart';

class _ValorCategoria {
  final String categoria;
  final double valor;
  const _ValorCategoria(this.categoria, this.valor);
}

class _GaussPonto {
  final double x;
  final double y;
  const _GaussPonto(this.x, this.y);
}

/// Widget genérico que renderiza UM card de gráfico BI — recebe os pontos
/// já buscados (`BiDataPoint`) e o tipo escolhido, e decide como agregar +
/// desenhar. É a contraparte "ao vivo" do `RelatorioChartRenderer` (que
/// desenha estático pra PNG em Relatórios) — aqui é sempre um widget
/// Syncfusion interativo dentro do grid.
///
/// Visual (eixos, grade, legenda, dica, paleta) vem de `bi_tema.dart`.
class BiChartWidget extends StatelessWidget {
  final DashboardCardModel card;
  final List<BiDataPoint> pontos;
  // Segunda série (linha do 2-eixos) ou categoria de segmentação (barra
  // segmentada) — `card.campoY`/`estatisticaY`, buscados à parte pelo
  // repositório. Vazio quando o card não usa segundo campo.
  final List<BiDataPoint> pontosSecundarios;

  const BiChartWidget({super.key, required this.card, required this.pontos, this.pontosSecundarios = const []});

  static const _semDados = VazioBi();

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) return _semDados;
    switch (card.tipoGrafico) {
      case TipoGraficoBi.pizza:
        return _buildPizza();
      case TipoGraficoBi.barra:
        return _buildBarra();
      case TipoGraficoBi.barraSegmentada:
        return _buildBarraSegmentada();
      case TipoGraficoBi.linhas:
        return _buildLinhas();
      case TipoGraficoBi.barraLinha2Eixos:
        return _buildBarraLinha2Eixos();
      case TipoGraficoBi.boxplot:
        return _buildBoxplot();
      case TipoGraficoBi.gauss:
        return _buildGauss();
      // Renderizado por BiGraficoPersonalizado (varias series), que o
      // DashboardCardView escolhe antes de chegar aqui.
      case TipoGraficoBi.personalizado:
        return _semDados;
      case null:
        return _semDados;
    }
  }

  CampoBiCatalogo? get _campoX => card.fonteChave != null && card.campoX != null ? buscarCampoBi(card.fonteChave!, card.campoX!) : null;
  CampoBiCatalogo? get _campoY => card.fonteChave != null && card.campoY != null ? buscarCampoBi(card.fonteChave!, card.campoY!) : null;

  /// Nome da série na legenda/dica: o campo medido (antes era "Barra"/"Linha").
  String _nomeCampo(CampoBiCatalogo? campo, String padrao) {
    if (campo == null) return padrao;
    return campo.unidade != null && campo.unidade!.isNotEmpty ? '${campo.rotulo} (${campo.unidade})' : campo.rotulo;
  }

  /// Soma ou média conforme o campo (GUT soma; medições fazem média).
  AgregacaoBi get _agregacao => _campoX?.agregacao ?? AgregacaoBi.media;

  Map<String, double> _agrupar() => DashboardBiRepository().agruparValores(pontos, card.agruparPor, agregacao: _agregacao);

  /// Muitas categorias no eixo X: gira os rótulos para não embolar.
  int _rotacao(int categorias) => categorias > 6 ? 45 : 0;

  DataLabelSettings _rotulosValor(int quantidade) => DataLabelSettings(
        // Com muitas barras os números se sobrepõem — a dica mostra o valor.
        isVisible: quantidade <= 12,
        textStyle: rotuloDadoBi,
        labelAlignment: ChartDataLabelAlignment.outer,
      );

  Widget _buildPizza() {
    final categorias = pontos.every((p) => p.valor != null) ? _agrupar() : DashboardBiRepository().contarCategorias(pontos).map((k, v) => MapEntry(k, v.toDouble()));
    if (categorias.isEmpty) return _semDados;
    final total = categorias.values.fold<double>(0, (a, b) => a + b);
    final dados = categorias.entries.map((e) => _ValorCategoria(e.key, total == 0 ? 0 : (e.value / total) * 100)).toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return SfCircularChart(
      palette: paletaBi,
      legend: legendaBi(posicao: LegendPosition.bottom),
      tooltipBehavior: dicaBi(formato: 'point.x: point.y%'),
      series: <CircularSeries>[
        // Borda branca entre as fatias: separa cores vizinhas parecidas.
        PieSeries<_ValorCategoria, String>(
          dataSource: dados,
          xValueMapper: (d, _) => d.categoria,
          yValueMapper: (d, _) => double.parse(d.valor.toStringAsFixed(1)),
          dataLabelMapper: (d, _) => '${d.valor.toStringAsFixed(0)}%',
          radius: '80%',
          strokeColor: Colors.white,
          strokeWidth: 2,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: rotuloDadoBi,
            connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '8%'),
          ),
        ),
      ],
    );
  }

  Widget _buildBarra() {
    final grupos = _agrupar();
    if (grupos.isEmpty) return _semDados;
    final dados = grupos.entries.map((e) => _ValorCategoria(e.key, e.value)).toList();
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      tooltipBehavior: dicaBi(),
      primaryXAxis: eixoCategoriaBi(rotacao: _rotacao(dados.length)),
      primaryYAxis: eixoNumericoBi(),
      series: <CartesianSeries>[
        ColumnSeries<_ValorCategoria, String>(
          name: _nomeCampo(_campoX, 'Valor'),
          dataSource: dados,
          xValueMapper: (d, _) => d.categoria,
          yValueMapper: (d, _) => d.valor,
          dataLabelMapper: (d, _) => formatarNumeroBi(d.valor),
          color: card.cor,
          width: dados.length <= 2 ? 0.4 : 0.7,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          dataLabelSettings: _rotulosValor(dados.length),
        ),
      ],
    );
  }

  String _chaveGrupo(BiDataPoint p) => switch (card.agruparPor) {
        'tipoElemento' => p.tipoElemento,
        'elemento' => p.elementoNome,
        _ => p.local,
      };

  Widget _buildBarraSegmentada() {
    // A categoria de segmentação vem do segundo campo (`campoY`), casada
    // por elemento com o campo principal — pedido explícito: escolher qual
    // categoria segmenta, não usar sempre a categoria do próprio campo X.
    // Sem segundo campo (cards antigos, ou fonte sem outro categórico),
    // cai no comportamento antigo: segmenta pela categoria do próprio ponto.
    final categoriaPorElemento = <String, String>{
      for (final s in pontosSecundarios)
        if (s.categoria != null) s.elementoId: s.categoria!,
    };
    final usaSecundario = categoriaPorElemento.isNotEmpty;

    // Altura de cada pedaço: o VALOR da variável naquele recorte, com a
    // agregação do campo — soma no GUT (os pedaços somam o total do grupo),
    // média nas medições. É o mesmo critério do gráfico personalizado (ver
    // `segmentarSerieBi`); aqui a barra sempre contava ocorrências, então um
    // cartão de "GUT (somatório)" mostrava 3, 5, 4 em vez do GUT somado.
    // Contagem continua sendo o certo quando a variável não tem número
    // (campo categórico, como "Anomalias"): aí o que há para empilhar é
    // quantas vezes cada categoria apareceu.
    final contar = pontos.every((p) => p.valor == null);
    final porCategoriaGrupo = <String, Map<String, List<double>>>{};
    for (final p in pontos) {
      if (!contar && p.valor == null) continue;
      final grupo = _chaveGrupo(p);
      final cat = usaSecundario ? (categoriaPorElemento[p.elementoId] ?? 'Sem dado') : (p.categoria ?? 'Sem dado');
      porCategoriaGrupo.putIfAbsent(grupo, () => {}).putIfAbsent(cat, () => []).add(p.valor ?? 1);
    }
    if (porCategoriaGrupo.isEmpty) return _semDados;

    double altura(String grupo, String cat) {
      final v = porCategoriaGrupo[grupo]?[cat];
      if (v == null || v.isEmpty) return 0;
      final soma = v.reduce((a, b) => a + b);
      return contar || _agregacao == AgregacaoBi.soma ? soma : soma / v.length;
    }

    final categorias = porCategoriaGrupo.values.expand((m) => m.keys).toSet().toList();
    final grupos = porCategoriaGrupo.keys.toList();
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      legend: legendaBi(),
      tooltipBehavior: dicaBi(),
      primaryXAxis: eixoCategoriaBi(rotacao: _rotacao(grupos.length)),
      primaryYAxis: eixoNumericoBi(titulo: contar ? 'Quantidade' : _nomeCampo(_campoX, 'Valor')),
      series: List.generate(categorias.length, (i) {
        final cat = categorias[i];
        return StackedColumnSeries<String, String>(
          name: cat,
          dataSource: grupos,
          xValueMapper: (g, _) => g,
          yValueMapper: (g, _) => altura(g, cat),
          // "Sem dado" em cinza neutro: não é uma categoria de verdade.
          color: cat == 'Sem dado' ? const Color(0xFFD5D5D5) : corDaPaletaBi(i),
          width: grupos.length <= 2 ? 0.4 : 0.7,
          borderRadius: i == categorias.length - 1 ? const BorderRadius.vertical(top: Radius.circular(6)) : BorderRadius.zero,
        );
      }),
    );
  }

  Widget _buildBarraLinha2Eixos() {
    final primarios = DashboardBiRepository().agruparValores(pontos, card.agruparPor, agregacao: _agregacao);
    if (primarios.isEmpty) return _semDados;
    final secundarios = pontosSecundarios.isEmpty
        ? <String, double>{}
        : DashboardBiRepository().agruparValores(
            pontosSecundarios,
            card.agruparPor,
            agregacao: _campoY?.agregacao ?? AgregacaoBi.media,
          );
    final grupos = primarios.keys.toList();
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      legend: legendaBi(visivel: secundarios.isNotEmpty),
      tooltipBehavior: dicaBi(),
      primaryXAxis: eixoCategoriaBi(rotacao: _rotacao(grupos.length)),
      primaryYAxis: eixoNumericoBi(),
      // Segundo eixo só quando existe a segunda série (antes aparecia vazio).
      axes: <ChartAxis>[if (secundarios.isNotEmpty) eixoNumericoBi(nome: 'secundario', oposto: true)],
      series: <CartesianSeries>[
        ColumnSeries<String, String>(
          name: _nomeCampo(_campoX, 'Valor'),
          dataSource: grupos,
          xValueMapper: (g, _) => g,
          yValueMapper: (g, _) => primarios[g],
          color: card.cor,
          width: grupos.length <= 2 ? 0.4 : 0.7,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        if (secundarios.isNotEmpty)
          LineSeries<String, String>(
            name: _nomeCampo(_campoY, 'Segundo valor'),
            dataSource: grupos,
            xValueMapper: (g, _) => g,
            yValueMapper: (g, _) => secundarios[g],
            yAxisName: 'secundario',
            color: kBiTinta,
            width: 2,
            markerSettings: const MarkerSettings(isVisible: true, color: Colors.white, borderColor: kBiTinta, borderWidth: 2),
          ),
      ],
    );
  }

  Widget _buildLinhas() {
    final comData = pontos.where((p) => p.data != null && p.valor != null).toList()..sort((a, b) => a.data!.compareTo(b.data!));
    if (comData.length >= 2) {
      // Campo com dimensão de tempo nativa (RDO) — linha ao longo das datas.
      final porSerie = <String, List<BiDataPoint>>{};
      for (final p in comData) {
        final serie = card.agruparPor == 'tipoElemento' ? p.tipoElemento : (card.agruparPor == 'local' ? p.local : 'Geral');
        porSerie.putIfAbsent(serie, () => []).add(p);
      }
      return SfCartesianChart(
        plotAreaBorderWidth: 0,
        legend: legendaBi(visivel: porSerie.length > 1),
        tooltipBehavior: dicaBi(),
        primaryXAxis: eixoDataBi(),
        primaryYAxis: eixoNumericoBi(),
        series: List.generate(porSerie.length, (i) {
          final nome = porSerie.keys.elementAt(i);
          final serie = porSerie[nome]!;
          final cor = porSerie.length == 1 ? card.cor : corDaPaletaBi(i);
          return LineSeries<BiDataPoint, DateTime>(
            name: porSerie.length == 1 ? _nomeCampo(_campoX, nome) : nome,
            dataSource: serie,
            xValueMapper: (d, _) => d.data,
            yValueMapper: (d, _) => d.valor,
            color: cor,
            width: 2.5,
            markerSettings: MarkerSettings(isVisible: true, color: Colors.white, borderColor: cor, borderWidth: 2),
          );
        }),
      );
    }

    // Sem dimensão de tempo (a maioria dos ensaios) — mesma agregação da
    // barra (por Local/Tipo de elemento/Elemento), só desenhada como linha.
    final grupos = _agrupar();
    if (grupos.isEmpty) return _semDados;
    final dados = grupos.entries.map((e) => _ValorCategoria(e.key, e.value)).toList();
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      tooltipBehavior: dicaBi(),
      primaryXAxis: eixoCategoriaBi(rotacao: _rotacao(dados.length)),
      primaryYAxis: eixoNumericoBi(),
      series: <CartesianSeries>[
        LineSeries<_ValorCategoria, String>(
          name: _nomeCampo(_campoX, 'Valor'),
          dataSource: dados,
          xValueMapper: (d, _) => d.categoria,
          yValueMapper: (d, _) => d.valor,
          color: card.cor,
          width: 2.5,
          markerSettings: MarkerSettings(isVisible: true, color: Colors.white, borderColor: card.cor, borderWidth: 2),
        ),
      ],
    );
  }

  Widget _buildBoxplot() {
    final porGrupo = <String, List<double>>{};
    for (final p in pontos) {
      if (p.valor == null) continue;
      final chave = card.agruparPor == 'tipoElemento' ? p.tipoElemento : p.local;
      porGrupo.putIfAbsent(chave, () => []).add(p.valor!);
    }
    final entradas = porGrupo.entries.where((e) => e.value.length >= 2).toList();
    if (entradas.isEmpty) return const VazioBi(texto: 'São precisos ao menos 2 valores por grupo');
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      tooltipBehavior: dicaBi(),
      primaryXAxis: eixoCategoriaBi(rotacao: _rotacao(entradas.length)),
      primaryYAxis: eixoNumericoBi(),
      series: <CartesianSeries>[
        BoxAndWhiskerSeries<MapEntry<String, List<double>>, String>(
          name: _nomeCampo(_campoX, 'Valor'),
          dataSource: entradas,
          xValueMapper: (e, _) => e.key,
          yValueMapper: (e, _) => e.value,
          showMean: true,
          boxPlotMode: BoxPlotMode.normal,
          color: card.cor.withValues(alpha: 0.35),
          borderColor: card.cor,
          borderWidth: 1.5,
          width: entradas.length <= 2 ? 0.35 : 0.6,
        ),
      ],
    );
  }

  Widget _buildGauss() {
    final valores = pontos.map((p) => p.valor).whereType<double>().toList();
    if (valores.length < 2) return const VazioBi(texto: 'São precisos ao menos 2 valores');
    final media = valores.reduce((a, b) => a + b) / valores.length;
    final desvio = sqrt(valores.map((v) => pow(v - media, 2)).reduce((a, b) => a + b) / valores.length);
    if (desvio == 0) return const VazioBi(texto: 'Todos os valores são iguais');
    final fck = media - 1.645 * desvio;
    final minX = (media - 4 * desvio).clamp(0, double.infinity).toDouble();
    final maxX = media + 4 * desvio;
    final passo = (maxX - minX) / 100;
    final curva = <_GaussPonto>[];
    double picoY = 0;
    for (double x = minX; x <= maxX; x += (passo == 0 ? 1 : passo)) {
      final y = (1 / (desvio * sqrt(2 * pi))) * exp(-0.5 * pow((x - media) / desvio, 2));
      if (y > picoY) picoY = y;
      curva.add(_GaussPonto(x, y));
    }
    const corFck = Color(0xFFB3261E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SfCartesianChart(
            plotAreaBorderWidth: 0,
            primaryXAxis: NumericAxis(
              majorGridLines: const MajorGridLines(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              axisLine: const AxisLine(color: kBiBorda),
              labelStyle: const TextStyle(fontSize: 9, color: kBiSuave),
            ),
            // Densidade de probabilidade: o número do eixo Y não diz nada a
            // quem lê o laudo, então o eixo fica escondido.
            primaryYAxis: const NumericAxis(isVisible: false, majorGridLines: MajorGridLines(width: 0)),
            series: <CartesianSeries>[
              SplineAreaSeries<_GaussPonto, double>(
                dataSource: curva,
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: card.cor.withValues(alpha: 0.18),
                borderColor: card.cor,
                borderWidth: 2,
              ),
              LineSeries<_GaussPonto, double>(dataSource: [_GaussPonto(media, 0), _GaussPonto(media, picoY * 1.05)], xValueMapper: (d, _) => d.x, yValueMapper: (d, _) => d.y, color: kBiTinta, dashArray: const [4, 3]),
              LineSeries<_GaussPonto, double>(dataSource: [_GaussPonto(fck, 0), _GaussPonto(fck, picoY * 1.05)], xValueMapper: (d, _) => d.x, yValueMapper: (d, _) => d.y, color: corFck, dashArray: const [6, 4]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _Legenda(cor: kBiTinta, texto: 'Média ${formatarNumeroBi(media)}'),
              _Legenda(cor: corFck, texto: 'fck ${formatarNumeroBi(fck)}'),
              _Legenda(cor: card.cor, texto: 'Desvio ${formatarNumeroBi(desvio)} · n=${valores.length}', tracejada: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String texto;
  final bool tracejada;

  const _Legenda({required this.cor, required this.texto, this.tracejada = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: tracejada ? 2 : 8,
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 10, color: kBiTexto, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
