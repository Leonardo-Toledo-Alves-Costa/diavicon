import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/ponto_medicao_model.dart';
import '../models/ponto_prova_carga_model.dart';

/// Renderiza a planta com a Área de Ensaio (retângulo) e os pontos de
/// medição (círculos numerados) sobrepostos. Usado na tela principal de
/// coleta — a marcação em si (arrastar/redimensionar) acontece nos modais
/// dedicados (`SelecionarAreaEnsaioModal` / `SelecionarPontoMedicaoModal`).
///
/// As coordenadas dos marcadores são frações (0-1) do tamanho *real* da
/// imagem (é assim que os modais de marcação as capturam, mostrando a
/// planta em tamanho natural). Por isso aqui a imagem precisa ser exibida
/// respeitando sua proporção original, sem cortes (`BoxFit.cover` cortaria
/// a imagem e desalinharia os marcadores) — resolvemos a proporção real via
/// `resolve`/`ImageStreamListener` e envolvemos tudo num `AspectRatio`.
class CroquiProvaCarga extends StatefulWidget {
  final ImageProvider? imagem;
  final PontoProvaCargaModel? area;
  final List<PontoMedicaoModel> pontos;
  final Map<String, bool> excedidoPorNome;
  final String? pontoSelecionadoNome;
  final ValueChanged<PontoMedicaoModel>? onTapPonto;
  final double maxHeight;

  const CroquiProvaCarga({
    super.key,
    required this.imagem,
    required this.area,
    required this.pontos,
    this.excedidoPorNome = const {},
    this.pontoSelecionadoNome,
    this.onTapPonto,
    this.maxHeight = 400,
  });

  @override
  State<CroquiProvaCarga> createState() => _CroquiProvaCargaState();
}

class _CroquiProvaCargaState extends State<CroquiProvaCarga> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolverImagem();
  }

  @override
  void didUpdateWidget(covariant CroquiProvaCarga oldWidget) {
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
        width: double.infinity,
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

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (widget.area != null)
                          Positioned(
                            left: (widget.area!.marcaX * w) - (widget.area!.marcaLargura * w / 2),
                            top: (widget.area!.marcaY * h) - (widget.area!.marcaAltura * h / 2),
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: widget.area!.marcaRotacao * (math.pi / 180),
                                child: Container(
                                  width: widget.area!.marcaLargura * w,
                                  height: widget.area!.marcaAltura * h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.22),
                                    border: Border.all(color: AppColors.primary, width: 2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ...widget.pontos.map((ponto) {
                          final excedeu = widget.excedidoPorNome[ponto.nome] ?? false;
                          final selecionado = ponto.nome == widget.pontoSelecionadoNome;
                          final Color cor = excedeu
                              ? Colors.red.shade700
                              : (selecionado ? Colors.deepOrange : AppColors.primary);
                          final numeroVisual = ponto.nome.replaceAll(RegExp(r'[^0-9]'), '');
                          // Diâmetro real marcado no slider "Tamanho da Marcação"
                          // (SelecionarPontoMedicaoModal), com piso mínimo pra
                          // continuar tocável em plantas pequenas.
                          final diametro = (ponto.tamanho * w).clamp(20.0, w);

                          return Positioned(
                            left: (ponto.x * w) - (diametro / 2),
                            top: (ponto.y * h) - (diametro / 2),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onTapPonto == null ? null : () => widget.onTapPonto!(ponto),
                              child: Container(
                                width: diametro,
                                height: diametro,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Center(
                                  child: Text(
                                    numeroVisual.isNotEmpty ? numeroVisual : '?',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: (diametro * 0.4).clamp(9.0, 22.0)),
                                  ),
                                ),
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
}
