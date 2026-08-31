import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/ponto_potencial_model.dart';
import '../repositories/potencial_repository.dart';
import '../widgets/heatmap_painter.dart'; 

class BoxPlotDataPotencial {
  final String x;
  final List<double> y;
  BoxPlotDataPotencial(this.x, this.y);
}

class AnalisePontoPotencialScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String local;
  
  final String projetoId;
  final String elementoId;
  final String tipoEnsaioId;

  const AnalisePontoPotencialScreen({
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
  ConsumerState<AnalisePontoPotencialScreen> createState() => _AnalisePontoPotencialScreenState();
}

class _AnalisePontoPotencialScreenState extends ConsumerState<AnalisePontoPotencialScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  
  bool _isLoading = true;
  bool _salvando = false;
  bool _isCapturing = false; 
  PontoPotencialModel? _modelo;

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
      final repo = ref.read(potencialRepositoryProvider);
      _modelo = await repo.buscarPontoPotencial(widget.pontoGeralId);
      
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

  Future<File?> _capturarImagemFinal() async {
    setState(() => _isCapturing = true); 
    await Future.delayed(const Duration(milliseconds: 150)); 

    try {
      RenderRepaintBoundary? boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0); 
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final buffer = byteData.buffer;
        final tempDir = Directory.systemTemp;
        File file = File('${tempDir.path}/mapa_potencial_final_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        return file;
      }
    } catch (e) {
      debugPrint('Erro ao capturar a imagem do mapa: $e');
    } finally {
      setState(() => _isCapturing = false); 
    }
    return null;
  }

  Future<void> _salvarAnalise() async {
    if (_modelo == null) return;
    setState(() => _salvando = true);
    
    try {
      final repo = ref.read(potencialRepositoryProvider);

      File? imagemFinal = await _capturarImagemFinal();
      String? urlImagemFinal = _modelo!.imagemElementoMapa;

      if (imagemFinal != null) {
        urlImagemFinal = await repo.uploadImagem(imagemFinal, 'potencial') ?? urlImagemFinal;
      }
      
      final modeloAtualizado = PontoPotencialModel(
        id: _modelo!.id,
        pontoEnsaioId: _modelo!.pontoEnsaioId,
        eletrodo: _modelo!.eletrodo,
        tempoSaturacao: _modelo!.tempoSaturacao,
        temperatura: _modelo!.temperatura,
        espacamentoX: _modelo!.espacamentoX,
        espacamentoY: _modelo!.espacamentoY,
        imagemElemento: _modelo!.imagemElemento,
        imagemEnsaio: _modelo!.imagemEnsaio,
        imagemElementoEnsaio: _modelo!.imagemElementoEnsaio,
        imagemMapaCalor: _modelo!.imagemMapaCalor,
        imagemElementoMapa: urlImagemFinal, 
        opacidade: _opacidade.toStringAsFixed(2),
        p1X: _p1.dx, p1Y: _p1.dy, 
        p2X: _p2.dx, p2Y: _p2.dy, 
        p3X: _p3.dx, p3Y: _p3.dy, 
        p4X: _p4.dx, p4Y: _p4.dy,
        leituras: _modelo!.leituras,
      );

      await repo.salvarPotencialCompleto(
        dados: modeloAtualizado,
        projetoId: widget.projetoId, 
        elementoId: widget.elementoId, 
        tipoEnsaioId: widget.tipoEnsaioId, 
        pontoNome: widget.pontoNome,
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calibração e Imagem salvas com sucesso!'), backgroundColor: Colors.green));
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

  List<HeatmapPoint> _getHeatmapPoints() {
    if (_modelo == null) return [];
    
    double espX = double.tryParse(_modelo!.espacamentoX ?? '10') ?? 10.0;
    double espY = double.tryParse(_modelo!.espacamentoY ?? '10') ?? 10.0;

    return _modelo!.leituras
        .where((l) => l.potencialMv != null)
        .map((l) => HeatmapPoint(l.coluna * espX, l.linha * espY, l.potencialMv!.abs()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final bool temFundo = _modelo?.imagemElemento != null && _modelo!.imagemElemento!.isNotEmpty;
    final heatmapPoints = _getHeatmapPoints();
    
    int maxCol = _modelo?.leituras.fold<int>(0, (prev, l) => max(prev, l.coluna)) ?? 1;
    int maxLin = _modelo?.leituras.fold<int>(0, (prev, l) => max(prev, l.linha)) ?? 1;
    double espX = double.tryParse(_modelo?.espacamentoX ?? '10') ?? 10.0;
    double espY = double.tryParse(_modelo?.espacamentoY ?? '10') ?? 10.0;
    double maxRealX = maxCol * espX;
    double maxRealY = maxLin * espY;

    // --- CÁLCULOS ESTATÍSTICOS ---
    // Converter leituras inseridas em módulo para valores negativos (Padrão Eletrodo)
    final leiturasValidas = _modelo?.leituras
        .where((l) => l.potencialMv != null)
        .map((l) => -l.potencialMv!.abs())
        .toList() ?? [];

    double media = 0.0;
    double menor = 0.0; // Valor mais negativo
    double maior = 0.0; // Valor mais próximo de 0
    double cv = 0.0;
    bool pilhaExistente = false;

    if (leiturasValidas.isNotEmpty) {
      media = leiturasValidas.reduce((a, b) => a + b) / leiturasValidas.length;
      menor = leiturasValidas.reduce(min);
      maior = leiturasValidas.reduce(max);
      
      // Pilha de corrosão macroscópica (diferença > 150mV)
      pilhaExistente = (maior - menor).abs() >= 150;

      if (leiturasValidas.length > 1 && media != 0) {
        double variance = leiturasValidas.map((e) => pow(e - media, 2)).reduce((a, b) => a + b) / leiturasValidas.length;
        cv = (sqrt(variance) / media.abs()) * 100;
      }
    }
    
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

            // --- 1. CARD RESUMO (MÉDIA, MAIOR, MENOR) ---
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
                        Text('Potencial de Corrosão', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        const SizedBox(height: 6),
                        Text('Maior: ${maior.toStringAsFixed(0)} mV | Menor: ${menor.toStringAsFixed(0)} mV', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey, height: 1.4)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Média', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                      Text('${media.toStringAsFixed(0)} mV', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. BOXPLOT ESTATÍSTICO HORIZONTAL ---
            if (leiturasValidas.isNotEmpty)
              Container(
                height: 180,
                //width: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: SfCartesianChart(
                  margin: EdgeInsets.all(20),
                  isTransposed: true,
                  plotAreaBorderWidth: 0,
                  primaryXAxis: const CategoryAxis(isVisible: false), 
                  primaryYAxis: NumericAxis(
                    minimum: -500,
                    maximum: 0,
                    interval: 100,
                    title: const AxisTitle(text: 'Potencial (mV)', textStyle: TextStyle(fontSize: 10, color: Colors.grey)),
                    axisLine: const AxisLine(width: 0),
                    plotBands: [
                      PlotBand(start: -500, end: -350, color: Colors.red.withValues(alpha: 0.1), text: 'Alta', textStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: -350, end: -200, color: Colors.orange.withValues(alpha: 0.15), text: 'Incerto', textStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                      PlotBand(start: -200, end: 60, color: Colors.green.withValues(alpha: 0.1), text: 'Baixo', textStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold), verticalTextAlignment: TextAnchor.middle, horizontalTextAlignment: TextAnchor.middle),
                    ]
                  ),
                  series: <BoxAndWhiskerSeries<BoxPlotDataPotencial, String>>[
                    BoxAndWhiskerSeries<BoxPlotDataPotencial, String>(
                      dataSource: [BoxPlotDataPotencial('', leiturasValidas)],
                      xValueMapper: (data, _) => data.x,
                      yValueMapper: (data, _) => data.y,
                      showMean: false,
                      color: Colors.orangeAccent.withValues(alpha: 0.5),
                      borderColor: Colors.orange,
                    )
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // --- 3. CARDS INFERIORES (PILHA DE CORROSÃO E COEF. DE VARIAÇÃO) ---
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Text('Pilha de corrosão', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: pilhaExistente ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            pilhaExistente ? 'Existente' : 'Inexistente',
                            style: GoogleFonts.lato(color: pilhaExistente ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
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

            // --- 4. SOBREPOSIÇÃO DO MAPA ---
            Text('Sobreposição do mapeamento', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 16),

            if (!temFundo)
             Container(
                height: 300, color: Colors.white,
                child: Center(child: Text('Nenhuma imagem "Base Mapa" inserida na Tela de Dados.', style: TextStyle(color: Colors.grey))),
              )
            else
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _imageSize = Size(constraints.maxWidth, constraints.maxWidth * 1.33); 
                      return RepaintBoundary(
                        key: _boundaryKey,
                        child: Stack(
                          children: [
                            Image.network(_modelo!.imagemElemento!, width: _imageSize.width, height: _imageSize.height, fit: BoxFit.cover),
                            
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
                                      ),
                                    ),
                              ),
                            ),

                            if (!_isCapturing) ...[
                              _buildDraggablePin(_p1, (val) => setState(() => _p1 = val)),
                              _buildDraggablePin(_p2, (val) => setState(() => _p2 = val)),
                              _buildDraggablePin(_p3, (val) => setState(() => _p3 = val)),
                              _buildDraggablePin(_p4, (val) => setState(() => _p4 = val)),
                            ]
                          ],
                        ),
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