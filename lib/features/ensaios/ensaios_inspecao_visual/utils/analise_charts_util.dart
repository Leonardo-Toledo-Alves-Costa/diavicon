import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/widgets/foto_ensaio.dart';
import '../widgets/iv_ui.dart';

/// Paleta, modelos e widgets de gráfico compartilhados pelas telas de
/// Análise (por Local e Geral) — fonte única pra evitar que os dois
/// dashboards divirjam nas cores/formas de agregação.

// Paleta da identidade Diavicon (cinza escuro + laranja) estendida com tons
// auxiliares para acomodar um número variável de séries/fatias.
const List<Color> paletaAnalise = [
  Color(0xFF3E3E3D),
  Color(0xFFFF7029),
  Color(0xFFF6BC66),
  Color(0xFF8B8B8B),
  Color(0xFF5C7A99),
  Color(0xFFB2555B),
];
const Color corOutrasAnalise = Color(0xFFD9D9D9);
const String bucketOutrasAnomalias = 'Outras anomalias';

// Models para os Gráficos Syncfusion
class ChartDataBar {
  final String categoria;
  final double valor;
  final Color cor;
  ChartDataBar(this.categoria, this.valor, this.cor);
}

class ChartDataPie {
  final String categoria;
  final double percentual;
  final Color cor;
  ChartDataPie(this.categoria, this.percentual, this.cor);
}

class AnomaliaDetalheModel {
  final String nome;
  final double areaAfetada;
  final int gut;
  final String riscoTipo;
  final String riscoClasse;
  final double majoracao;

  AnomaliaDetalheModel({
    required this.nome, required this.areaAfetada, required this.gut,
    required this.riscoTipo, required this.riscoClasse, required this.majoracao,
  });
}

/// Um registro de inspeção visual pronto pra exibição na aba Tabelas —
/// usado tanto pela análise de um único Local quanto pela análise Geral
/// (que também mostra de qual local cada registro veio, via [localNome]).
class RegistroAnaliseModel {
  final String id;
  final String nomeRegistro;
  final String descricao;
  final String plantaUrl;
  final String? localNome;
  final String sistemaNome;
  final String tipoElementoNome;
  final String elementoNome;
  final List<String> fotosGaleria;
  final int gutTotal;
  final List<AnomaliaDetalheModel> anomalias;

  RegistroAnaliseModel({
    required this.id, required this.nomeRegistro, required this.descricao, required this.plantaUrl, this.localNome,
    required this.sistemaNome, required this.tipoElementoNome, required this.elementoNome,
    required this.fotosGaleria, required this.gutTotal, required this.anomalias,
  });
}

/// A relação `tipos_elemento` (e o `sistemas_habitacionais` aninhado dentro
/// dela) às vezes vem como Map (relação para-um) e às vezes como List —
/// normaliza os dois formatos, mesmo padrão usado em inspecao_visual_local_screen.dart.
Map<String, dynamic>? extrairEmbedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
    return raw.first as Map<String, dynamic>;
  }
  return null;
}

/// Converte um mapa {categoria: soma de G.U.T.} em fatias de pizza
/// ponderadas pelo percentual daquele total (não por contagem de ocorrências).
List<ChartDataPie> paraPizza(Map<String, double> valores, double total) {
  if (total <= 0) return [];
  final entradas = valores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return List.generate(entradas.length, (i) {
    final pct = double.parse(((entradas[i].value / total) * 100).toStringAsFixed(1));
    return ChartDataPie(entradas[i].key, pct, paletaAnalise[i % paletaAnalise.length]);
  });
}

/// As N categorias (tipo de elemento / sistema / local) de maior G.U.T. somado.
List<String> topNCategorias(Map<String, double> valores, int n) {
  final ordenado = valores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return ordenado.take(n).map((e) => e.key).toList();
}

void abrirImagemAmpliada(BuildContext context, String url) {
  abrirFotoTelaCheia(context, [StorageNetworkImage(url)]);
}

Widget pizzaChart(List<ChartDataPie> dados) {
  if (dados.isEmpty) {
    return const Center(child: Text('Sem dados suficientes', style: TextStyle(color: Colors.grey)));
  }
  return SfCircularChart(
    series: <CircularSeries>[
      PieSeries<ChartDataPie, String>(
        dataSource: dados,
        xValueMapper: (ChartDataPie data, _) => data.categoria,
        yValueMapper: (ChartDataPie data, _) => data.percentual,
        pointColorMapper: (ChartDataPie data, _) => data.cor,
        dataLabelMapper: (ChartDataPie data, _) => '${data.categoria}\n${data.percentual}%',
        dataLabelSettings: const DataLabelSettings(
          isVisible: true,
          labelPosition: ChartDataLabelPosition.outside,
          textStyle: TextStyle(fontSize: 10, color: Colors.black87),
          connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve),
        ),
      )
    ],
  );
}

Widget empilhadoChart({
  required List<String> eixoX,
  required Map<String, Map<String, double>> dadosPorCategoria,
  required List<String> series,
  required List<Color> cores,
  required String tituloEixoX,
  bool rotacionarRotulos = false,
}) {
  if (eixoX.isEmpty || series.isEmpty) {
    return const Center(child: Text('Sem dados suficientes', style: TextStyle(color: Colors.grey)));
  }
  return SfCartesianChart(
    legend: const Legend(isVisible: true, position: LegendPosition.top, iconHeight: 12, iconWidth: 12, overflowMode: LegendItemOverflowMode.wrap),
    primaryXAxis: CategoryAxis(
      majorGridLines: const MajorGridLines(width: 0),
      labelRotation: rotacionarRotulos ? 45 : 0,
      title: AxisTitle(text: tituloEixoX, textStyle: const TextStyle(fontSize: 10)),
    ),
    primaryYAxis: const NumericAxis(
      minimum: 0,
      axisLine: AxisLine(width: 0),
      title: AxisTitle(text: 'Pontuação GUT', textStyle: TextStyle(fontSize: 10)),
    ),
    series: List.generate(series.length, (i) {
      final nomeSerie = series[i];
      final ultima = i == series.length - 1;
      return StackedColumnSeries<MapEntry<String, double>, String>(
        name: nomeSerie,
        color: cores[i],
        dataSource: eixoX.map((x) => MapEntry(x, dadosPorCategoria[x]?[nomeSerie] ?? 0.0)).toList(),
        xValueMapper: (MapEntry<String, double> e, _) => e.key,
        yValueMapper: (MapEntry<String, double> e, _) => e.value,
        borderRadius: ultima ? const BorderRadius.vertical(top: Radius.circular(6)) : BorderRadius.zero,
      );
    }),
  );
}

/// Cor determinística (não aleatória) pra cada barra de um gráfico simples,
/// ciclando pela paleta — usado no gráfico "G.U.T. por Local".
Color corDaPaleta(int i) => paletaAnalise[i % paletaAnalise.length];

/// Card de um registro de inspeção na aba Tabelas: lê como uma ficha de
/// laudo (dados em "rótulo: valor", não em campos de formulário), com a
/// planta marcada, as fotos e as anomalias sempre à vista. Mostra o Local
/// quando [RegistroAnaliseModel.localNome] vem preenchido (análise Geral,
/// que cruza vários locais).
class RegistroAnaliseCard extends StatelessWidget {
  final RegistroAnaliseModel registro;

  const RegistroAnaliseCard({super.key, required this.registro});

  @override
  Widget build(BuildContext context) {
    final gut = registro.gutTotal.toDouble();
    final faixa = FaixaGut.de(gut);
    final fotos = [for (final u in registro.fotosGaleria) ResizeImage(StorageNetworkImage(u), width: 1600, policy: ResizeImagePolicy.fit)];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kIvBorda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faixa superior na cor da criticidade.
          Container(height: 5, color: faixa.cor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (registro.localNome != null && registro.localNome!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.place_outlined, size: 14, color: kIvLaranjaTexto),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      registro.localNome!,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kIvLaranjaTexto),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(registro.nomeRegistro, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kIvTinta)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SeloGut(valor: gut, mostrarFaixa: true),
                  ],
                ),
                if (registro.descricao.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(registro.descricao, style: const TextStyle(fontSize: 13, color: kIvTexto, height: 1.45)),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, c) {
                    final planta = _Planta(url: registro.plantaUrl, lado: c.maxWidth < 420 ? 110 : 140);
                    final dados = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Dado(rotulo: 'Sistema', valor: registro.sistemaNome),
                        _Dado(rotulo: 'Tipo de elemento', valor: registro.tipoElementoNome),
                        _Dado(rotulo: 'Elemento', valor: registro.elementoNome, ultimo: true),
                      ],
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [planta, const SizedBox(width: 14), Expanded(child: dados)],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  fotos.isEmpty ? 'Sem fotos' : 'Fotos (${fotos.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kIvSuave),
                ),
                if (fotos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GradeFotosEnsaio(
                    imagens: [for (final u in registro.fotosGaleria) ResizeImage(StorageNetworkImage(u), width: 320)],
                    tamanhoMinimo: 72,
                  ),
                ],
              ],
            ),
          ),
          // Anomalias sempre visíveis: é o conteúdo principal da análise.
          Container(
            color: const Color(0xFFFAFAF8),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.report_gmailerrorred_outlined, size: 16, color: kIvSuave),
                    const SizedBox(width: 6),
                    Text(
                      registro.anomalias.isEmpty
                          ? 'Sem anomalias'
                          : 'Anomalias e manifestações (${registro.anomalias.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kIvSuave),
                    ),
                  ],
                ),
                for (final ano in registro.anomalias) ...[
                  const SizedBox(height: 8),
                  _LinhaAnomalia(anomalia: ano),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Planta extends StatelessWidget {
  final String url;
  final double lado;

  const _Planta({required this.url, required this.lado});

  @override
  Widget build(BuildContext context) {
    final tem = url.isNotEmpty;
    return Tooltip(
      message: tem ? 'Ampliar planta' : 'Sem marcação em planta',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: tem ? () => abrirImagemAmpliada(context, url) : null,
        child: Container(
          width: lado,
          height: lado,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kIvBorda),
          ),
          child: !tem
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, color: kIvSuave),
                    SizedBox(height: 4),
                    Text('Sem planta', style: TextStyle(fontSize: 11, color: kIvSuave)),
                  ],
                )
              // `contain`: a planta com a marcação aparece inteira.
              : ImagemStorage.network(
                  url,
                  cacheWidth: 480,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: kIvSuave)),
                  loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
        ),
      ),
    );
  }
}

class _Dado extends StatelessWidget {
  final String rotulo;
  final String valor;
  final bool ultimo;

  const _Dado({required this.rotulo, required this.valor, this.ultimo = false});

  @override
  Widget build(BuildContext context) {
    final vazio = valor.trim().isEmpty || valor == '-';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: ultimo ? null : const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: const TextStyle(fontSize: 11, color: kIvSuave)),
          const SizedBox(height: 2),
          Text(
            vazio ? 'Não informado' : valor,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: vazio ? kIvSuave : kIvTinta),
          ),
        ],
      ),
    );
  }
}

class _LinhaAnomalia extends StatelessWidget {
  final AnomaliaDetalheModel anomalia;

  const _LinhaAnomalia({required this.anomalia});

  @override
  Widget build(BuildContext context) {
    final classe = anomalia.riscoClasse.toLowerCase();
    final corClasse = switch (classe) {
      'alto' => const Color(0xFFB3261E),
      'médio' || 'medio' => const Color(0xFFB26A00),
      'baixo' => const Color(0xFF2E7D32),
      _ => kIvSuave,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kIvBorda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(anomalia.nome, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kIvTinta))),
              const SizedBox(width: 8),
              SeloGut(valor: anomalia.gut.toDouble()),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EtiquetaIv(texto: 'Área ${_pct(anomalia.areaAfetada)}', icone: Icons.crop_free_rounded),
              if (anomalia.majoracao > 0) EtiquetaIv(texto: 'Majoração ${_pct(anomalia.majoracao)}', icone: Icons.trending_up_rounded),
              EtiquetaIv(
                texto: 'Risco ${anomalia.riscoTipo.toLowerCase()} · $classe',
                icone: Icons.shield_outlined,
                cor: corClasse,
                fundo: corClasse.withValues(alpha: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';
}
