import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../ensaios_potencial_corrosao/widgets/heatmap_painter.dart';
import '../models/ponto_medicao_model.dart';

/// Mapa de calor da Área de Ensaio: intensidade = deslocamento máximo de
/// cada ponto de medição, posicionado sobre a planta nas mesmas
/// coordenadas fracionárias usadas pelo croqui (reaproveita o
/// `HeatmapPainter`/IDW já usado no ensaio de potencial de corrosão).
///
/// Mesma lógica de `CroquiProvaCarga` para não cortar a imagem: resolve a
/// proporção real e envolve tudo num `AspectRatio`.
class MapaCalorProvaCarga extends StatefulWidget {
  final ImageProvider? imagem;
  final List<PontoMedicaoModel> pontos;
  final Map<String, int> deslocamentoMaximoPorNome;
  final double maxHeight;

  const MapaCalorProvaCarga({
    super.key,
    required this.imagem,
    required this.pontos,
    required this.deslocamentoMaximoPorNome,
    this.maxHeight = 320,
  });

  @override
  State<MapaCalorProvaCarga> createState() => _MapaCalorProvaCargaState();
}

class _MapaCalorProvaCargaState extends State<MapaCalorProvaCarga> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolverImagem();
  }

  @override
  void didUpdateWidget(covariant MapaCalorProvaCarga oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagem != widget.imagem) {
      setState(() => _aspectRatio = null);
      _resolverImagem();
    }
  }

  void _resolverImagem() {
    final imagem = widget.imagem;
    if (imagem == null) return;
    _stream?.removeListener(_listener!);
    _stream = imagem.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _aspectRatio = w / h);
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagem == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Planta não disponível', style: TextStyle(color: Colors.grey))),
      );
    }
    if (_aspectRatio == null) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: AspectRatio(
          aspectRatio: _aspectRatio!,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: widget.imagem!, fit: BoxFit.fill),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;

                    final heatmapPoints = widget.pontos
                        .map((p) => HeatmapPoint(p.x * w, p.y * h, (widget.deslocamentoMaximoPorNome[p.nome] ?? 0).toDouble()))
                        .toList();
                    final maiorDeslocamento = heatmapPoints.isEmpty
                        ? 1.0
                        : heatmapPoints.map((p) => p.value).reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (heatmapPoints.isNotEmpty)
                          CustomPaint(
                            size: Size(w, h),
                            painter: HeatmapPainter(
                              points: heatmapPoints,
                              maxX: w,
                              maxY: h,
                              opacity: 0.55,
                              colorMapper: (value) => _corDeslocamento(value / maiorDeslocamento),
                            ),
                          ),
                        ...widget.pontos.map((ponto) {
                          final numero = ponto.nome.replaceAll(RegExp(r'[^0-9]'), '');
                          return Positioned(
                            left: (ponto.x * w) - 12,
                            top: (ponto.y * h) - 12,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                numero,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Verde (pouco deslocamento) -> Amarelo -> Vermelho (próximo do maior
  // deslocamento registrado entre os pontos desta área de ensaio).
  Color _corDeslocamento(double fracao) {
    final t = fracao.clamp(0.0, 1.0);
    if (t <= 0.5) {
      return Color.lerp(Colors.green.shade600, Colors.yellow.shade700, t / 0.5) ?? Colors.yellow;
    }
    return Color.lerp(Colors.orange, Colors.red.shade900, (t - 0.5) / 0.5) ?? Colors.red;
  }
}
