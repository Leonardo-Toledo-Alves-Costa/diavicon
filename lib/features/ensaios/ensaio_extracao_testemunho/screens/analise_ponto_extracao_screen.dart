import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/extracao_model.dart';
import '../repositories/extracao_repository.dart';

class _BarraResistencia {
  final String rotulo;
  final double valor;
  _BarraResistencia(this.rotulo, this.valor);
}

class _GaussPonto {
  final double x;
  final double y;
  _GaussPonto(this.x, this.y);
}

// Análise individual do ensaio de Extração — carrega os dados por conta
// própria via pontoGeralId (mesmo padrão dos demais ensaios "por local/
// estrutura" — ver `AnalisePontoChumbadorScreen`). Como este ensaio já é
// escopado a UM local (ver `ExtracaoLocalModel`), o filtro aqui é só por
// Tipo de elemento — o filtro por Local, pedido pelo usuário, se aplica na
// Análise Geral (que cruza vários locais).
class AnalisePontoExtracaoScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String localNome;

  const AnalisePontoExtracaoScreen({super.key, required this.pontoGeralId, required this.localNome});

  @override
  ConsumerState<AnalisePontoExtracaoScreen> createState() => _AnalisePontoExtracaoScreenState();
}

class _AnalisePontoExtracaoScreenState extends ConsumerState<AnalisePontoExtracaoScreen> {
  bool _isLoading = true;
  ExtracaoLocalModel? _local;
  String _filtroTipo = 'Tipos de elemento';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      _local = await ref.read(extracaoRepositoryProvider).buscarPontoExtracao(widget.pontoGeralId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double _desvioPadrao(List<double> v) {
    if (v.length < 2) return 0;
    final m = _media(v);
    return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length);
  }

  double _normalPdf(double x, double media, double desvio) {
    if (desvio <= 0) return 0;
    final expo = -pow(x - media, 2) / (2 * desvio * desvio);
    return (1 / (desvio * sqrt(2 * pi))) * exp(expo);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final todos = _local?.leiturasOrdenadas ?? const <LeituraExtracaoModel>[];
    final tipos = ['Tipos de elemento', ...todos.map((p) => p.tipoElemento).where((t) => t.isNotEmpty).toSet()];
    final pontos = todos.where((p) => _filtroTipo == 'Tipos de elemento' || p.tipoElemento == _filtroTipo).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Análise',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Extração de testemunho', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text(widget.localNome, style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarDados,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDropdown(_filtroTipo, tipos, (v) => setState(() => _filtroTipo = v!)),
              const SizedBox(height: 16),
              _buildGraficoBarras(pontos),
              const SizedBox(height: 24),
              _buildGraficoFck(pontos),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGraficoBarras(List<LeituraExtracaoModel> pontos) {
    final dados = pontos.where((p) => p.resistenciaComCorrecao != null).map((p) => _BarraResistencia('${p.nomeTestemunho}\n${p.elementoNome}', p.resistenciaComCorrecao!)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resistência corrigida por ponto', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 12),
          if (dados.length < 2)
            SizedBox(height: 200, child: Center(child: Text('Cadastre ao menos 2 pontos (com resistência corrigida) para comparar.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 280,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(labelStyle: GoogleFonts.lato(fontSize: 10, color: Colors.grey.shade700)),
                primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Resistência corrigida (MPa)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                series: <CartesianSeries>[
                  ColumnSeries<_BarraResistencia, String>(
                    dataSource: dados,
                    xValueMapper: (d, _) => d.rotulo,
                    yValueMapper: (d, _) => d.valor,
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                    dataLabelSettings: const DataLabelSettings(isVisible: true, textStyle: TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraficoFck(List<LeituraExtracaoModel> pontos) {
    final valores = pontos.map((p) => p.resistenciaComCorrecao).whereType<double>().toList();

    if (valores.length < 2) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
        child: Text('É preciso ao menos 2 pontos com resistência corrigida pra estimar o fck.', textAlign: TextAlign.center, style: GoogleFonts.lato(color: Colors.grey, fontSize: 12)),
      );
    }

    final media = _media(valores);
    final desvio = _desvioPadrao(valores);
    final fck = media - 1.645 * desvio;
    final minX = (media - 4 * desvio).clamp(0, double.infinity).toDouble();
    final maxX = media + 4 * desvio;
    final passo = (maxX - minX) / 100;

    final curva = <_GaussPonto>[];
    double picoY = 0;
    for (double x = minX; x <= maxX; x += (passo == 0 ? 1 : passo)) {
      final y = _normalPdf(x, media, desvio);
      if (y > picoY) picoY = y;
      curva.add(_GaussPonto(x, y));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: SfCartesianChart(
              title: ChartTitle(text: 'fck estimado: ${fck.toStringAsFixed(1)} MPa', textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D))),
              primaryXAxis: const NumericAxis(title: AxisTitle(text: 'Resistência corrigida (MPa)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
              primaryYAxis: const NumericAxis(title: AxisTitle(text: 'Densidade de probabilidade', textStyle: TextStyle(fontSize: 10, color: Colors.grey)), majorGridLines: MajorGridLines(width: 0)),
              series: <CartesianSeries>[
                SplineAreaSeries<_GaussPonto, double>(
                  dataSource: curva,
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: const Color(0x333F51B5),
                  borderColor: const Color(0xFF3F51B5),
                  borderWidth: 2,
                ),
                LineSeries<_GaussPonto, double>(
                  dataSource: [_GaussPonto(media, 0), _GaussPonto(media, picoY * 1.05)],
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: const Color(0xFF3F51B5),
                  dashArray: const [4, 3],
                  width: 1.5,
                ),
                LineSeries<_GaussPonto, double>(
                  dataSource: [_GaussPonto(fck, 0), _GaussPonto(fck, picoY * 1.05)],
                  xValueMapper: (d, _) => d.x,
                  yValueMapper: (d, _) => d.y,
                  color: Colors.red,
                  dashArray: const [6, 4],
                  width: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
