import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/custom_empty_state.dart';
import '../models/leitura_prova_carga_model.dart';
import '../models/ponto_medicao_model.dart';
import '../providers/prova_carga_providers.dart';
import '../utils/analise_prova_carga_utils.dart';
import '../widgets/mapa_calor_prova_carga.dart';

/// Análise da Área de Ensaio (todos os pontos de medição marcados nela):
/// gráfico de deslocamento x carga por ponto, mapa de calor dos
/// deslocamentos máximos sobre a planta, tabela de leituras e ranking de
/// deslocamento entre os pontos.
class AnaliseProvaCargaScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;

  const AnaliseProvaCargaScreen({super.key, required this.pontoGeralId});

  @override
  ConsumerState<AnaliseProvaCargaScreen> createState() => _AnaliseProvaCargaScreenState();
}

class _AnaliseProvaCargaScreenState extends ConsumerState<AnaliseProvaCargaScreen> {
  bool _isLoading = true;
  int _abaSelecionada = 0;
  String? _pontoSelecionadoNome;

  String _nomePonto = '';
  List<PontoMedicaoModel> _pontosMedicao = [];
  List<LeituraProvaCargaModel> _leituras = [];
  ImageProvider? _plantaImagem;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final repo = ref.read(provaCargaRepositoryProvider);
      final dados = await repo.carregarPonto(widget.pontoGeralId);

      _nomePonto = dados['nomePonto'] ?? '';
      _pontosMedicao = List<PontoMedicaoModel>.from(dados['pontosMedicao']);
      _leituras = List<LeituraProvaCargaModel>.from(dados['leituras']);
      if (_pontosMedicao.isNotEmpty) _pontoSelecionadoNome = _pontosMedicao.first.nome;

      final area = dados['area'];
      final plantaUrl = area?.plantaFoto as String?;
      if (plantaUrl != null && plantaUrl.isNotEmpty) {
        if (plantaUrl.toLowerCase().contains('.pdf')) {
          await _carregarPdf(plantaUrl);
        } else {
          _plantaImagem = StorageNetworkImage(plantaUrl);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar análise: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarPdf(String url) async {
    try {
      final req = await HttpClient().getUrl(Uri.parse(await StorageUrls.assinar(url)));
      final doc = await PdfDocument.openData(await consolidateHttpClientResponseBytes(await req.close()));
      final page = await doc.getPage(1);
      double w = page.width;
      double h = page.height;
      if (w < 1000) {
        w *= 2.0;
        h *= 2.0;
      }
      const maxDim = 2500.0;
      if (w > maxDim || h > maxDim) {
        final prop = w / h;
        if (w > h) {
          w = maxDim;
          h = maxDim / prop;
        } else {
          h = maxDim;
          w = maxDim * prop;
        }
      }
      final pageImg = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
      if (pageImg != null) _plantaImagem = MemoryImage(pageImg.bytes);
      await page.close();
      await doc.close();
    } catch (e) {
      debugPrint('Erro PDF: $e');
    }
  }

  Map<String, List<LeituraProvaCargaModel>> get _leiturasAgrupadas {
    final map = <String, List<LeituraProvaCargaModel>>{};
    for (final l in _leituras) {
      map.putIfAbsent(l.pontoMedicaoNome, () => []).add(l);
    }
    return map;
  }

  List<EstatisticasPontoMedicao> get _estatisticasPorPonto =>
      _pontosMedicao.map((p) => calcularEstatisticasPonto(p, _leituras)).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Análise', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Prova de Carga Estática', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCabecalho(),
          _buildAbas(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: switch (_abaSelecionada) {
                0 => _buildAbaGraficos(),
                1 => _buildAbaTabelas(),
                _ => _buildAbaEstatisticas(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(_nomePonto, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          ),
          const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
        ],
      ),
    );
  }

  Widget _buildAbas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            _buildTabBotao(0, 'Gráficos'),
            _buildTabBotao(1, 'Tabelas'),
            _buildTabBotao(2, 'Estatísticas'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBotao(int index, String titulo) {
    final sel = _abaSelecionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaSelecionada = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(24)),
          alignment: Alignment.center,
          child: Text(titulo, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: sel ? Colors.white : const Color(0xFF686868))),
        ),
      ),
    );
  }

  // ==========================================
  // ABA 1: GRÁFICOS
  // ==========================================
  Widget _buildAbaGraficos() {
    if (_pontosMedicao.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhum ponto de medição criado.'));
    }

    final leiturasDoSelecionado = _leiturasAgrupadas[_pontoSelecionadoNome] ?? [];
    final leiturasCarregamento = leiturasDoSelecionado.where((l) => l.etapa == 'Carregamento').toList()
      ..sort((a, b) => a.carregamento.compareTo(b.carregamento));
    final leiturasDescarregamento = leiturasDoSelecionado.where((l) => l.etapa == 'Descarregamento').toList()
      ..sort((a, b) => b.carregamento.compareTo(a.carregamento));
    final dadosGraficoDescarregamento = [
      if (leiturasCarregamento.isNotEmpty) leiturasCarregamento.last,
      ...leiturasDescarregamento,
    ];

    final pontoSelecionado = _pontosMedicao.firstWhere(
      (p) => p.nome == _pontoSelecionadoNome,
      orElse: () => _pontosMedicao.first,
    );
    final stats = calcularEstatisticasPonto(pontoSelecionado, _leituras);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _pontoSelecionadoNome,
              items: _pontosMedicao.map((p) => DropdownMenuItem(value: p.nome, child: Text(p.nome))).toList(),
              onChanged: (val) => setState(() => _pontoSelecionadoNome = val),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: SizedBox(
            height: 250,
            child: SfCartesianChart(
              primaryXAxis: NumericAxis(
                title: AxisTitle(text: 'Carga (kg)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                majorGridLines: const MajorGridLines(width: 0),
              ),
              primaryYAxis: NumericAxis(
                title: AxisTitle(text: 'Deslocamento (mm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                axisLine: const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
                isInversed: true,
              ),
              legend: Legend(isVisible: true, position: LegendPosition.top),
              series: [
                LineSeries<LeituraProvaCargaModel, num>(
                  name: 'Carregamento',
                  dataSource: leiturasCarregamento,
                  xValueMapper: (l, _) => l.carregamento,
                  yValueMapper: (l, _) => l.deslocamento,
                  color: const Color(0xFFFFA726),
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
                LineSeries<LeituraProvaCargaModel, num>(
                  name: 'Descarregamento',
                  dataSource: dadosGraficoDescarregamento,
                  xValueMapper: (l, _) => l.carregamento,
                  yValueMapper: (l, _) => l.deslocamento,
                  color: const Color(0xFF1B2A4A),
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _cardEstatistica('Carregamento máximo', '${stats.cargaMaxima} kg')),
            const SizedBox(width: 12),
            Expanded(child: _cardEstatistica('Duração do ensaio', formatarDuracao(stats.duracaoEnsaio))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _cardEstatistica('Deslocamento máximo', '${stats.deslocamentoMaximo} mm', destaque: stats.excedeuDeformacaoMaxima)),
            const SizedBox(width: 12),
            Expanded(child: _cardEstatistica('Residual máximo', stats.deslocamentoResidual != null ? '${stats.deslocamentoResidual} mm' : '-')),
          ],
        ),
        const SizedBox(height: 24),

        Text('Mapa de calor — deslocamento máximo', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 12),
        MapaCalorProvaCarga(
          imagem: _plantaImagem,
          pontos: _pontosMedicao,
          deslocamentoMaximoPorNome: {for (final e in _estatisticasPorPonto) e.ponto.nome: e.deslocamentoMaximo},
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _cardEstatistica(String label, String valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: destaque ? Border.all(color: Colors.red.shade200) : null,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            valor,
            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: destaque ? Colors.red.shade700 : const Color(0xFF3E3E3D)),
          ),
          if (destaque) ...[
            const SizedBox(height: 4),
            Text('Excedeu a deformação máxima', style: TextStyle(fontSize: 9, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TABELAS
  // ==========================================
  Widget _buildAbaTabelas() {
    if (_pontosMedicao.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhum ponto de medição criado.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _pontosMedicao.map((ponto) {
        final leituras = List<LeituraProvaCargaModel>.from(_leiturasAgrupadas[ponto.nome] ?? [])
          ..sort((a, b) {
            final etapaCompare = a.etapa.compareTo(b.etapa);
            return etapaCompare != 0 ? etapaCompare : a.carregamento.compareTo(b.carregamento);
          });

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '${ponto.nome}${ponto.tipoElemento != null ? ' — ${ponto.tipoElemento}' : ''}',
                  style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                ),
              ),
              if (leituras.isEmpty)
                const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text('Nenhuma leitura registrada.', style: TextStyle(color: Colors.grey, fontSize: 13)))
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Table(
                    columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(3), 3: FlexColumnWidth(2)},
                    children: [
                      const TableRow(children: [
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Desloc.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Carga', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Etapa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Hora', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                      ]),
                      ...leituras.map((l) => TableRow(children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${l.deslocamento} mm', style: const TextStyle(fontSize: 13))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('${l.carregamento} kg', style: const TextStyle(fontSize: 13))),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                l.etapa,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: l.etapa == 'Carregamento' ? const Color(0xFFFFA726) : const Color(0xFF1B2A4A)),
                              ),
                            ),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l.horario, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                          ])),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==========================================
  // ABA 3: ESTATÍSTICAS
  // ==========================================
  Widget _buildAbaEstatisticas() {
    if (_pontosMedicao.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhum ponto de medição criado.'));
    }

    final ranking = List<EstatisticasPontoMedicao>.from(_estatisticasPorPonto)
      ..sort((a, b) => b.deslocamentoMaximo.compareTo(a.deslocamentoMaximo));
    final maiorValor = ranking.first.deslocamentoMaximo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Deslocamento máximo por ponto de medição', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 16),
        ...ranking.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          final fracao = maiorValor == 0 ? 0.0 : stat.deslocamentoMaximo / maiorValor;
          final isMaior = index == 0;
          final isMenor = index == ranking.length - 1 && ranking.length > 1;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(stat.ponto.nome, style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ),
                    if (isMaior)
                      _badge('Maior deslocamento', Colors.red)
                    else if (isMenor)
                      _badge('Menor deslocamento', Colors.green),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fracao,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(isMaior ? Colors.red.shade600 : AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${stat.deslocamentoMaximo} mm', style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _badge(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: cor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cor)),
    );
  }
}
