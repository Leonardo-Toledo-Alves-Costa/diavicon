import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/chumbador_model.dart';
import '../repositories/chumbador_repository.dart';

class _PontoForcaDeslocamento {
  final double deslocamento;
  final double forca;
  _PontoForcaDeslocamento(this.deslocamento, this.forca);
}

// Análise individual do ensaio de Tração em Chumbador — carrega os dados
// por conta própria via pontoGeralId (mesmo padrão de
// `AnalisePontoMonitoramentoFissuraScreen`/`AnalisePontoPotencialScreen`),
// acessível pelo botão "Análise" no drawer da tela de coleta. Carga máxima,
// deslocamento máximo e o gráfico força×deslocamento ficam só aqui — a
// coleta mostra apenas dados brutos e a lista de leituras.
class AnalisePontoChumbadorScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;

  const AnalisePontoChumbadorScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
  });

  @override
  ConsumerState<AnalisePontoChumbadorScreen> createState() => _AnalisePontoChumbadorScreenState();
}

class _AnalisePontoChumbadorScreenState extends ConsumerState<AnalisePontoChumbadorScreen> {
  bool _isLoading = true;
  ChumbadorModel? _ensaio;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      _ensaio = await ref.read(chumbadorRepositoryProvider).buscarPontoChumbador(widget.pontoGeralId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final ensaio = _ensaio ?? const ChumbadorModel();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Análise',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tração em Chumbador', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text('${widget.pontoNome} - ${widget.elementoNome}', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
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
              Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
              Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildCardResultado('Carga máxima', ensaio.cargaMaxima != null ? '${ensaio.cargaMaxima!.toStringAsFixed(1)} kN' : '-')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCardResultado('Deslocamento máx.', ensaio.deslocamentoMaximo != null ? '${ensaio.deslocamentoMaximo!.toStringAsFixed(1)} mm' : '-')),
                ],
              ),
              const SizedBox(height: 24),
              _buildGraficoForcaDeslocamento(ensaio),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardResultado(String rotulo, String valor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(valor, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  Widget _buildGraficoForcaDeslocamento(ChumbadorModel ensaio) {
    final carregamento = ensaio.leiturasCarregamento.map((l) => _PontoForcaDeslocamento(l.deslocamentoMm, l.forcaKn)).toList();
    final descarregamentoLido = ensaio.leiturasDescarregamento.map((l) => _PontoForcaDeslocamento(l.deslocamentoMm, l.forcaKn)).toList();
    // Liga o último ponto do carregamento ao primeiro do descarregamento —
    // é a mesma curva contínua do ensaio (o pico), não duas curvas soltas.
    final descarregamento = carregamento.isNotEmpty && descarregamentoLido.isNotEmpty
        ? [carregamento.last, ...descarregamentoLido]
        : descarregamentoLido;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Força × deslocamento', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 12),
          if (carregamento.isEmpty && descarregamento.isEmpty)
            SizedBox(height: 200, child: Center(child: Text('Sem leituras ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 280,
              child: SfCartesianChart(
                legend: const Legend(isVisible: true, position: LegendPosition.top),
                primaryXAxis: NumericAxis(title: const AxisTitle(text: 'Deslocamento (mm)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                primaryYAxis: NumericAxis(title: const AxisTitle(text: 'Força (kN)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                series: <CartesianSeries>[
                  LineSeries<_PontoForcaDeslocamento, double>(
                    name: 'Carregamento',
                    dataSource: carregamento,
                    xValueMapper: (d, _) => d.deslocamento,
                    yValueMapper: (d, _) => d.forca,
                    color: EtapaLeituraChumbador.carregamento.cor,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
                  ),
                  LineSeries<_PontoForcaDeslocamento, double>(
                    name: 'Descarregamento',
                    dataSource: descarregamento,
                    xValueMapper: (d, _) => d.deslocamento,
                    yValueMapper: (d, _) => d.forca,
                    color: EtapaLeituraChumbador.descarregamento.cor,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
