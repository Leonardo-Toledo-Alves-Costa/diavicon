import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/custom_empty_state.dart';
import '../models/esclerometria_model.dart';

class _BoxPlotData {
  final String x;
  final List<double> y;
  _BoxPlotData(this.x, this.y);
}

/// Análise de um ponto de esclerometria: gráfico de barras das leituras
/// (cinza = desconsiderada/rejeitada) com linha de média, tabela e boxplot
/// — mesmo padrão (BoxAndWhiskerSeries) já usado na análise de resistividade.
class AnaliseEsclerometriaScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;

  const AnaliseEsclerometriaScreen({super.key, required this.pontoGeralId});

  @override
  ConsumerState<AnaliseEsclerometriaScreen> createState() => _AnaliseEsclerometriaScreenState();
}

class _AnaliseEsclerometriaScreenState extends ConsumerState<AnaliseEsclerometriaScreen> {
  static const double _limiarRejeicao = 0.10;

  bool _isLoading = true;
  int _abaSelecionada = 0;

  String _nomePonto = '';
  String _elementoNome = '';
  String _tipoElemento = '';
  String _local = '';
  int _indiceK = 1;
  List<EsclerometriaLeituraModel> _leituras = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final supabase = Supabase.instance.client;

      final geral = await supabase
          .from('pontos_ensaios_geral')
          .select('nome_ponto, elementos_estruturais(nome, tipo, local)')
          .eq('id', widget.pontoGeralId)
          .maybeSingle();

      _nomePonto = geral?['nome_ponto'] ?? '';
      final elemento = geral?['elementos_estruturais'] as Map<String, dynamic>?;
      _elementoNome = elemento?['nome'] ?? '';
      _tipoElemento = elemento?['tipo'] ?? '-';
      _local = elemento?['local'] ?? '-';

      final esc = await supabase
          .from('ponto_ensaio_esclerometria')
          .select('id, indice_k')
          .eq('ponto_geral_id', widget.pontoGeralId)
          .maybeSingle();

      _indiceK = (esc?['indice_k'] as num?)?.toInt() ?? 1;
      final esclerometriaId = esc?['id']?.toString();

      if (esclerometriaId != null) {
        final leiturasResp = await supabase
            .from('ponto_ensaio_esclerometria_leituras')
            .select('*')
            .eq('ponto_id', esclerometriaId)
            .order('criado_em', ascending: true);

        _leituras = (leiturasResp as List).map((l) => EsclerometriaLeituraModel.fromJson(l)).toList();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar análise: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _mediaGeral {
    if (_leituras.isEmpty) return 0;
    final soma = _leituras.fold<int>(0, (a, b) => a + b.valorQ);
    return soma / _leituras.length;
  }

  double _delta(EsclerometriaLeituraModel l) {
    final media = _mediaGeral;
    if (media == 0) return 0;
    return (l.valorQ - media) / media;
  }

  bool _aceita(EsclerometriaLeituraModel l) => _delta(l).abs() <= _limiarRejeicao;

  List<EsclerometriaLeituraModel> get _validas => _leituras.where(_aceita).toList();

  double get _mediaValida {
    final v = _validas;
    if (v.isEmpty) return 0;
    final soma = v.fold<int>(0, (a, b) => a + b.valorQ);
    return soma / v.length;
  }

  double get _desvioPadraoValidas {
    final v = _validas;
    if (v.length < 2) return 0;
    final media = _mediaValida;
    final somaQuad = v.fold<double>(0, (a, l) => a + (l.valorQ - media) * (l.valorQ - media));
    return math.sqrt(somaQuad / v.length);
  }

  double get _coefVariacao {
    final media = _mediaValida;
    if (media == 0) return 0;
    return (_desvioPadraoValidas / media) * 100;
  }

  double get _indiceEsclerometricoFinal => _mediaValida * _indiceK;

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
            Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Esclerometria', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_nomePonto - $_elementoNome', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                Text('$_tipoElemento\n$_local', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
              ],
            ),
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
    if (_leituras.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhuma leitura coletada.'));
    }

    final media = _mediaGeral;
    final isHomogeneo = _coefVariacao <= 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
          child: SizedBox(
            height: 280,
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(majorGridLines: MajorGridLines(width: 0)),
              primaryYAxis: NumericAxis(
                title: const AxisTitle(text: 'Índice esclerométrico (Q)', textStyle: TextStyle(fontSize: 10, color: Colors.grey)),
                plotBands: [
                  PlotBand(
                    start: media,
                    end: media,
                    borderWidth: 2,
                    borderColor: const Color(0xFF1B2A4A),
                    dashArray: const [6, 4],
                    text: 'Média: ${media.toStringAsFixed(1)}',
                    textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1B2A4A)),
                    horizontalTextAlignment: TextAnchor.end,
                    verticalTextPadding: '-4',
                  ),
                ],
              ),
              series: <CartesianSeries>[
                ColumnSeries<EsclerometriaLeituraModel, String>(
                  dataSource: _leituras,
                  xValueMapper: (l, i) => 'L${i + 1}',
                  yValueMapper: (l, _) => l.valorQ,
                  pointColorMapper: (l, _) => _aceita(l) ? AppColors.primary : Colors.grey.shade400,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _cardEstatistica('Índice Esclerométrico', _validas.isEmpty ? '-' : _indiceEsclerometricoFinal.toStringAsFixed(1))),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                child: Column(
                  children: [
                    const Text('Coef. de variação', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text('${_coefVariacao.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                        style: TextStyle(fontSize: 10, color: isHomogeneo ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardEstatistica(String label, String valor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(valor, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TABELAS
  // ==========================================
  Widget _buildAbaTabelas() {
    if (_leituras.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhuma leitura coletada.'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
        children: [
          const TableRow(children: [
            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Leitura', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Valor (Q)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Desvio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
          ]),
          ...List.generate(_leituras.length, (i) {
            final l = _leituras[i];
            final delta = _delta(l);
            final aceita = _aceita(l);
            return TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('L${i + 1}', style: const TextStyle(fontSize: 13))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${l.valorQ}', style: const TextStyle(fontSize: 13))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: Colors.grey))),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: aceita ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(aceita ? 'aceita' : 'rejeitada', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: aceita ? Colors.green.shade800 : Colors.red.shade800)),
                ),
              ),
            ]);
          }),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 3: ESTATÍSTICAS (Boxplot)
  // ==========================================
  Widget _buildAbaEstatisticas() {
    if (_leituras.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 32), child: CustomEmptyState(text: 'Nenhuma leitura coletada.'));
    }

    final valores = _leituras.map((l) => l.valorQ.toDouble()).toList();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SfCartesianChart(
        title: const ChartTitle(
          text: 'Distribuição das leituras esclerométricas',
          textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D)),
        ),
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Índice esclerométrico (Q)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
        series: <CartesianSeries>[
          BoxAndWhiskerSeries<_BoxPlotData, String>(
            dataSource: [_BoxPlotData('Leituras', valores)],
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            boxPlotMode: BoxPlotMode.normal,
            showMean: true,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
