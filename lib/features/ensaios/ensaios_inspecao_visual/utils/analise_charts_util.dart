import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            child: Image.network(
              url,
              errorBuilder: (c, e, s) => const Padding(
                padding: EdgeInsets.all(32),
                child: Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
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

/// Card de um registro de inspeção na aba Tabelas — planta com marcação
/// (foto_marcacao), galeria de fotos e anomalias, todos ampliáveis. Mostra
/// um selo com o nome do Local quando [RegistroAnaliseModel.localNome] vem
/// preenchido (análise Geral, que cruza vários locais).
class RegistroAnaliseCard extends StatelessWidget {
  final RegistroAnaliseModel registro;

  const RegistroAnaliseCard({super.key, required this.registro});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (registro.localNome != null && registro.localNome!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: Color(0xFFFFA726)),
                      const SizedBox(width: 4),
                      Text(registro.localNome!, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFA726))),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                _campoTexto(registro.nomeRegistro),
                const SizedBox(height: 5),
                _campoTexto(registro.descricao, minLines: 3),
                const SizedBox(height: 5),

                // PLANTA (COM MARCAÇÃO) E INFORMAÇÕES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: registro.plantaUrl.isEmpty ? null : () => abrirImagemAmpliada(context, registro.plantaUrl),
                      child: Container(
                        width: 120,
                        height: 120,
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: registro.plantaUrl.isEmpty
                            ? const Center(child: Icon(Icons.map_outlined, color: Colors.grey))
                            : Image.network(
                                registro.plantaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campoTexto(registro.sistemaNome, isSmall: true),
                          const SizedBox(height: 6),
                          _campoTexto(registro.tipoElementoNome, isSmall: true),
                          const SizedBox(height: 6),
                          _campoTexto(registro.elementoNome, isSmall: true),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 5),

                // GALERIA
                SizedBox(
                  height: 50,
                  child: registro.fotosGaleria.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Sem fotos', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade400)),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: registro.fotosGaleria.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final url = registro.fotosGaleria[idx];
                            return GestureDetector(
                              onTap: () => abrirImagemAmpliada(context, url),
                              child: Container(
                                width: 50,
                                height: 50,
                                clipBehavior: Clip.hardEdge,
                                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 20),
                                  loadingBuilder: (c, child, progress) => progress == null
                                      ? child
                                      : const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // EXPANSION TILE ANOMALIAS
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.orange.shade50.withValues(alpha: 0.3),
              ),
              child: ExpansionTile(
                title: Row(
                  children: [
                    const Text('Anomalias e manifestações', style: TextStyle(fontSize: 12, color: Color(0xFF3E3E3D))),
                    const Spacer(),
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    const Text('G.U.T ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${registro.gutTotal}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                children: registro.anomalias.map((ano) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ano.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF3E3E3D))),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Área afetada ${ano.areaAfetada.toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                const Text('G.U.T ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('${ano.gut}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                              child: Text('Risco ${ano.riscoTipo} ${ano.riscoClasse}', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                              child: Text('Majoração ${ano.majoracao.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _campoTexto(String text, {int minLines = 1, bool isSmall = false}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isSmall ? 4 : 8),
      border: Border.all(color: Colors.grey.shade300),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Text(text, style: TextStyle(fontSize: isSmall ? 12 : 14, color: const Color(0xFF3E3E3D))),
  );
}
