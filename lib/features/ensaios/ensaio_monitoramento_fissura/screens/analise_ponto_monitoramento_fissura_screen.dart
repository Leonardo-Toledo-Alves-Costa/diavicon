import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/monitoramento_fissura_model.dart';
import '../repositories/monitoramento_fissura_repository.dart';

class _PontoTempo {
  final DateTime data;
  final double valor;
  _PontoTempo(this.data, this.valor);
}

class _PontoXY {
  final double x;
  final double y;
  _PontoXY(this.x, this.y);
}

// Análise individual do ponto de Monitoramento de Fissuras — mesmo padrão
// de acesso (botão "Análise" no drawer do ensaio, dados recarregados por
// conta própria via pontoGeralId) já usado por
// `AnalisePontoPotencialScreen`/`AnalisePontosEnsaiosCarbonatacaoScreen`. Os
// gráficos aqui eram antes mostrados direto na tela de coleta
// (`PontoMonitoramentoFissuraScreen`) — movidos pra cá só pra manter o
// padrão do resto do app (coleta x análise em telas separadas).
class AnalisePontoMonitoramentoFissuraScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;

  const AnalisePontoMonitoramentoFissuraScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
  });

  @override
  ConsumerState<AnalisePontoMonitoramentoFissuraScreen> createState() => _AnalisePontoMonitoramentoFissuraScreenState();
}

class _AnalisePontoMonitoramentoFissuraScreenState extends ConsumerState<AnalisePontoMonitoramentoFissuraScreen> {
  bool _isLoading = true;
  String _eixoSelecionado = 'X';
  InstalacaoFissuraModel? _instalacao;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      _instalacao = await ref.read(monitoramentoFissuraRepositoryProvider).buscarInstalacao(widget.pontoGeralId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final medicoes = _instalacao?.medicoesOrdenadas ?? const <MedicaoFissuraModel>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Análise',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Monitoramento de Fissuras', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
              _buildGraficoMovimentoXY(medicoes),
              const SizedBox(height: 24),
              _buildGraficoDeslocamentoTempo(medicoes),
            ],
          ),
        ),
      ),
    );
  }

  // Gráfico cartesiano X/Y com 0 no centro — plota o caminho (medidaX,
  // medidaY) de cada medição em ordem cronológica (linha conectando os
  // pontos, mostrando a deformação ao longo do tempo) e destaca o último
  // ponto com um marcador maior/vermelho.
  Widget _buildGraficoMovimentoXY(List<MedicaoFissuraModel> medicoes) {
    final pontos = medicoes.map((m) => _PontoXY(m.medidaX, m.medidaY)).toList();
    final maiorAbs = pontos.isEmpty
        ? 0.2
        : pontos.expand((p) => [p.x.abs(), p.y.abs()]).reduce(max).clamp(0.2, double.infinity);
    final limite = (maiorAbs * 1.4);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Movimento em torno do eixo', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 4),
          Text('Trajetória do selo (X, Y) — o ponto vermelho é a leitura mais recente.', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),
          if (pontos.isEmpty)
            SizedBox(height: 200, child: Center(child: Text('Sem medições ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 260,
              child: SfCartesianChart(
                primaryXAxis: NumericAxis(minimum: -limite, maximum: limite, crossesAt: 0, title: const AxisTitle(text: 'Eixo X (mm)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                primaryYAxis: NumericAxis(minimum: -limite, maximum: limite, crossesAt: 0, title: const AxisTitle(text: 'Eixo Y (mm)', textStyle: TextStyle(fontSize: 10, color: Colors.grey))),
                series: <CartesianSeries>[
                  LineSeries<_PontoXY, double>(
                    dataSource: pontos,
                    xValueMapper: (d, _) => d.x,
                    yValueMapper: (d, _) => d.y,
                    color: AppColors.primary,
                    width: 2,
                    markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
                  ),
                  ScatterSeries<_PontoXY, double>(
                    dataSource: [pontos.last],
                    xValueMapper: (d, _) => d.x,
                    yValueMapper: (d, _) => d.y,
                    color: Colors.red,
                    markerSettings: const MarkerSettings(isVisible: true, width: 12, height: 12, shape: DataMarkerType.circle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGraficoDeslocamentoTempo(List<MedicaoFissuraModel> medicoes) {
    final pontos = medicoes
        .where((m) => m.dataHora != null)
        .map((m) => _PontoTempo(m.dataHora!, _eixoSelecionado == 'X' ? m.medidaX : m.medidaY))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Deslocamento', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    _buildBotaoEixo('X'),
                    _buildBotaoEixo('Y'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pontos.isEmpty)
            SizedBox(height: 180, child: Center(child: Text('Sem medições ainda.', style: GoogleFonts.lato(color: Colors.grey))))
          else
            SizedBox(
              height: 220,
              child: SfCartesianChart(
                primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
                primaryYAxis: NumericAxis(title: AxisTitle(text: 'Eixo $_eixoSelecionado (mm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey))),
                series: <CartesianSeries>[
                  SplineAreaSeries<_PontoTempo, DateTime>(
                    dataSource: pontos,
                    xValueMapper: (d, _) => d.data,
                    yValueMapper: (d, _) => d.valor,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderColor: AppColors.primary,
                    borderWidth: 2,
                    markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6, color: AppColors.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotaoEixo(String eixo) {
    final selecionado = _eixoSelecionado == eixo;
    return GestureDetector(
      onTap: () => setState(() => _eixoSelecionado = eixo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: selecionado ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20), boxShadow: selecionado ? const [BoxShadow(color: Colors.black12, blurRadius: 3)] : null),
        child: Text('Eixo $eixo', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: selecionado ? AppColors.primary : Colors.grey.shade600)),
      ),
    );
  }
}
