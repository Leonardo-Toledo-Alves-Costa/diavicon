import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../../core/widgets/custom_appbar.dart';
import '../../../ensaios_potencial_corrosao/widgets/heatmap_painter.dart';
import '../models/ultrassom_mapeamento_model.dart';
import '../repositories/ultrassom_mapeamento_repository.dart';

class BoxPlotDataUltrassom {
  final String x;
  final List<double> y;
  BoxPlotDataUltrassom(this.x, this.y);
}

// Espelha `AnalisePontoPotencialScreen` (perspectiva + mapa de calor +
// boxplot), adaptado pra velocidade de pulso ultrassônico (m/s, escala
// invertida em relação ao potencial: maior é melhor). Diferente de
// Potencial, a tabela `ponto_ensaio_ultrassom_mapeamento` não tem uma coluna
// pra guardar a imagem final composta — só a calibração (p1-p4/opacidade) é
// persistida aqui; a imagem de base (foto "Marcação da área") já foi salva
// na tela de coleta.
class AnalisePontoUltrassomMapeamentoScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String local;

  final String projetoId;
  final String elementoId;
  final String tipoEnsaioId;

  const AnalisePontoUltrassomMapeamentoScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.local,
    required this.projetoId,
    required this.elementoId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<AnalisePontoUltrassomMapeamentoScreen> createState() => _AnalisePontoUltrassomMapeamentoScreenState();
}

class _AnalisePontoUltrassomMapeamentoScreenState extends ConsumerState<AnalisePontoUltrassomMapeamentoScreen> {
  bool _isLoading = true;
  bool _salvando = false;
  PontoUltrassomMapeamentoModel? _modelo;

  double _opacidade = 0.6;
  Offset _p1 = const Offset(0.1, 0.1);
  Offset _p2 = const Offset(0.9, 0.1);
  Offset _p3 = const Offset(0.9, 0.9);
  Offset _p4 = const Offset(0.1, 0.9);

  Size _imageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(ultrassomMapeamentoRepositoryProvider);
      _modelo = await repo.buscarPontoMapeamento(widget.pontoGeralId);

      if (_modelo != null) {
        _opacidade = double.tryParse(_modelo!.opacidade ?? '0.6') ?? 0.6;
        if (_modelo!.p1X != null && _modelo!.p1Y != null) {
          _p1 = Offset(_modelo!.p1X!, _modelo!.p1Y!);
          _p2 = Offset(_modelo!.p2X!, _modelo!.p2Y!);
          _p3 = Offset(_modelo!.p3X!, _modelo!.p3Y!);
          _p4 = Offset(_modelo!.p4X!, _modelo!.p4Y!);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarAnalise() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _salvando ? null : _salvarAnalise`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer,
    // disparando dois UPDATEs concorrentes em `ponto_ensaio_ultrassom_mapeamento`
    // pra calibração/opacidade. Setar `_salvando` aqui é síncrono (setState
    // muda o campo na hora, só o rebuild é adiado), então a segunda chamada
    // já vê `_salvando == true` e sai antes de salvar de novo.
    if (_salvando) return;
    if (_modelo == null) return;
    setState(() => _salvando = true);

    try {
      final repo = ref.read(ultrassomMapeamentoRepositoryProvider);

      final modeloAtualizado = _modelo!.copyWith(
        opacidade: _opacidade.toStringAsFixed(2),
        p1X: _p1.dx, p1Y: _p1.dy,
        p2X: _p2.dx, p2Y: _p2.dy,
        p3X: _p3.dx, p3Y: _p3.dy,
        p4X: _p4.dx, p4Y: _p4.dy,
      );

      await repo.salvarMapeamentoCompleto(
        dados: modeloAtualizado,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        pontoNome: widget.pontoNome,
      );

      if (mounted) {
        setState(() => _modelo = modeloAtualizado);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calibração e Resultado salvos com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Matrix4 _calcularMatrizPerspectiva(Size size, Offset pt1, Offset pt2, Offset pt3, Offset pt4) {
    if (size.width == 0 || size.height == 0) return Matrix4.identity();
    double w = size.width, h = size.height;
    double x1 = pt1.dx * w, y1 = pt1.dy * h;
    double x2 = pt2.dx * w, y2 = pt2.dy * h;
    double x3 = pt3.dx * w, y3 = pt3.dy * h;
    double x4 = pt4.dx * w, y4 = pt4.dy * h;

    double dx1 = x2 - x3, dx2 = x4 - x3, dx3 = x1 - x2 + x3 - x4;
    double dy1 = y2 - y3, dy2 = y4 - y3, dy3 = y1 - y2 + y3 - y4;
    double det = dx1 * dy2 - dx2 * dy1;
    if (det == 0) return Matrix4.identity();

    double a13 = (dx3 * dy2 - dx2 * dy3) / det, a23 = (dx1 * dy3 - dx3 * dy1) / det;
    double a11 = x2 - x1 + a13 * x2, a21 = x4 - x1 + a23 * x4, a31 = x1;
    double a12 = y2 - y1 + a13 * y2, a22 = y4 - y1 + a23 * y4, a32 = y1;

    return Matrix4(a11 / w, a12 / w, 0, a13 / w, a21 / h, a22 / h, 0, a23 / h, 0, 0, 1, 0, a31, a32, 0, 1);
  }

  // Verde (rápido/melhor) -> vermelho (lento/pior) — igual à classificação
  // Whitehurst (Excelente >4500, Ótimo 3500-4500, Bom 3000-3500, Regular
  // 2000-3000, Ruim <2000), mas em gradiente contínuo pro mapa de calor.
  Color _corVelocidade(double v) {
    if (v <= 2000) return Color.lerp(Colors.red.shade900, Colors.red, (v / 2000).clamp(0.0, 1.0)) ?? Colors.red;
    if (v <= 3000) return Color.lerp(Colors.red, Colors.orange, (v - 2000) / 1000) ?? Colors.orange;
    if (v <= 3500) return Color.lerp(Colors.orange, Colors.yellow, (v - 3000) / 500) ?? Colors.yellow;
    if (v <= 4500) return Color.lerp(Colors.yellow, Colors.lightGreen, (v - 3500) / 1000) ?? Colors.lightGreen;
    final t = ((v - 4500) / 1000).clamp(0.0, 1.0);
    return Color.lerp(Colors.lightGreen, Colors.green.shade800, t) ?? Colors.green;
  }

  List<HeatmapPoint> _getHeatmapPoints() {
    if (_modelo == null) return [];

    double espX = double.tryParse(_modelo!.espacamentoX ?? '10') ?? 10.0;
    double espY = double.tryParse(_modelo!.espacamentoY ?? '10') ?? 10.0;

    return _modelo!.leituras
        .where((l) => l.velocidade != null)
        .map((l) => HeatmapPoint(l.coluna * espX, l.linha * espY, l.velocidade!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool temFundo = _modelo?.foto1 != null && _modelo!.foto1!.isNotEmpty;
    final heatmapPoints = _getHeatmapPoints();

    int maxCol = _modelo?.leituras.fold<int>(0, (prev, l) => max(prev, l.coluna)) ?? 1;
    int maxLin = _modelo?.leituras.fold<int>(0, (prev, l) => max(prev, l.linha)) ?? 1;
    double espX = double.tryParse(_modelo?.espacamentoX ?? '10') ?? 10.0;
    double espY = double.tryParse(_modelo?.espacamentoY ?? '10') ?? 10.0;
    double maxRealX = maxCol * espX;
    double maxRealY = maxLin * espY;

    final leiturasValidas = _modelo?.leituras.where((l) => l.velocidade != null).map((l) => l.velocidade!).toList() ?? [];

    double media = _modelo?.mediaVelocidade ?? 0.0;
    double maior = _modelo?.maiorVelocidade ?? 0.0;
    double menor = _modelo?.menorVelocidade ?? 0.0;
    double cv = _modelo?.coefVariacao ?? 0.0;
    final bool isHomogeneo = cv <= 15.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(title: 'Análise de Mapa de Calor', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.pontoNome} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            Text(widget.local, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mapeamento com ultrassom', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        const SizedBox(height: 6),
                        Text('Maior: ${maior.toStringAsFixed(0)} m/s | Menor: ${menor.toStringAsFixed(0)} m/s', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey, height: 1.4)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Média', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                      Text('${media.toStringAsFixed(0)} m/s', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (leiturasValidas.isNotEmpty)
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: SfCartesianChart(
                  margin: const EdgeInsets.all(20),
                  isTransposed: true,
                  plotAreaBorderWidth: 0,
                  primaryXAxis: const CategoryAxis(isVisible: false),
                  primaryYAxis: NumericAxis(
                    minimum: 0,
                    maximum: 6000,
                    interval: 1000,
                    title: const AxisTitle(text: 'Velocidade (m/s)', textStyle: TextStyle(fontSize: 10, color: Colors.grey)),
                    axisLine: const AxisLine(width: 0),
                    plotBands: [
                      PlotBand(start: 0, end: 2000, color: Colors.red.withValues(alpha: 0.1), text: 'Ruim', textStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: 2000, end: 3000, color: Colors.orange.withValues(alpha: 0.12), text: 'Regular', textStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: 3000, end: 3500, color: Colors.yellow.withValues(alpha: 0.18), text: 'Bom', textStyle: const TextStyle(color: Color(0xFFB08D00), fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: 3500, end: 4500, color: Colors.lightGreen.withValues(alpha: 0.15), text: 'Ótimo', textStyle: const TextStyle(color: Colors.lightGreen, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: 4500, end: 6000, color: Colors.green.withValues(alpha: 0.1), text: 'Excelente', textStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                    ],
                  ),
                  series: <BoxAndWhiskerSeries<BoxPlotDataUltrassom, String>>[
                    BoxAndWhiskerSeries<BoxPlotDataUltrassom, String>(
                      dataSource: [BoxPlotDataUltrassom('', leiturasValidas)],
                      xValueMapper: (data, _) => data.x,
                      yValueMapper: (data, _) => data.y,
                      showMean: false,
                      color: Colors.orangeAccent.withValues(alpha: 0.5),
                      borderColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text('Classificação', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          media > 0 ? _classificacaoTexto(media) : '-',
                          style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: media > 0 ? _corVelocidade(media) : Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text('Coef.de variação', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${cv.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                                style: GoogleFonts.lato(color: isHomogeneo ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Text('Sobreposição do mapeamento', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 16),

            if (!temFundo)
              Container(
                height: 300, color: Colors.white,
                child: const Center(child: Text('Nenhuma foto "Marcação da área" inserida na tela de coleta.', style: TextStyle(color: Colors.grey))),
              )
            else
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _imageSize = Size(constraints.maxWidth, constraints.maxWidth * 1.33);
                      return Stack(
                        children: [
                          ImagemStorage.network(_modelo!.foto1!, width: _imageSize.width, height: _imageSize.height, fit: BoxFit.cover),
                          Positioned.fill(
                            child: Transform(
                              transform: _calcularMatrizPerspectiva(_imageSize, _p1, _p2, _p3, _p4),
                              child: heatmapPoints.isEmpty
                                  ? const SizedBox()
                                  : CustomPaint(
                                      size: Size(_imageSize.width, _imageSize.height),
                                      painter: HeatmapPainter(
                                        points: heatmapPoints,
                                        maxX: maxRealX == 0 ? 100 : maxRealX,
                                        maxY: maxRealY == 0 ? 100 : maxRealY,
                                        opacity: _opacidade,
                                        resolution: 15,
                                        colorMapper: _corVelocidade,
                                      ),
                                    ),
                            ),
                          ),
                          _buildDraggablePin(_p1, (val) => setState(() => _p1 = val)),
                          _buildDraggablePin(_p2, (val) => setState(() => _p2 = val)),
                          _buildDraggablePin(_p3, (val) => setState(() => _p3 = val)),
                          _buildDraggablePin(_p4, (val) => setState(() => _p4 = val)),
                        ],
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),

            Row(
              children: [
                const Icon(Icons.opacity, color: Colors.grey),
                Expanded(child: Slider(value: _opacidade, min: 0.1, max: 1.0, activeColor: Colors.orange, onChanged: (v) => setState(() => _opacidade = v))),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _salvando ? null : _salvarAnalise,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA726),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _salvando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Salvar Calibração e Resultado', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _classificacaoTexto(double v) {
    if (v > 4500) return 'Excelente';
    if (v > 3500) return 'Ótimo';
    if (v > 3000) return 'Bom';
    if (v > 2000) return 'Regular';
    return 'Ruim';
  }

  Widget _buildDraggablePin(Offset offsetRelativo, Function(Offset) onUpdate) {
    double absX = offsetRelativo.dx * _imageSize.width;
    double absY = offsetRelativo.dy * _imageSize.height;

    return Positioned(
      left: absX - 20, top: absY - 20,
      child: GestureDetector(
        onPanUpdate: (details) {
          double newAbsX = (absX + details.delta.dx).clamp(0.0, _imageSize.width);
          double newAbsY = (absY + details.delta.dy).clamp(0.0, _imageSize.height);
          onUpdate(Offset(newAbsX / _imageSize.width, newAbsY / _imageSize.height));
        },
        child: Container(
          width: 40, height: 40, color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(width: 16, height: 16, decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        ),
      ),
    );
  }
}
