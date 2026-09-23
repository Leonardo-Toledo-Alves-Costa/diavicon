import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/extracao_model.dart';

/// Renderiza a planta com os testemunhos já extraídos marcados como
/// círculos numerados — mesmo padrão de `CroquiProvaCarga`, sem o retângulo
/// de área (este ensaio não tem "área de ensaio", só pontos individuais).
///
/// As coordenadas (`posX`/`posY`) são frações (0-1) do tamanho *real* da
/// imagem, por isso a planta é exibida respeitando sua proporção original
/// (`AspectRatio`), sem cortes.
class CroquiExtracao extends StatefulWidget {
  final ImageProvider? imagem;
  final List<LeituraExtracaoModel> pontosOrdenados;
  final ValueChanged<LeituraExtracaoModel>? onTapPonto;
  final double maxHeight;

  const CroquiExtracao({
    super.key,
    required this.imagem,
    required this.pontosOrdenados,
    this.onTapPonto,
    this.maxHeight = 320,
  });

  @override
  State<CroquiExtracao> createState() => _CroquiExtracaoState();
}

class _CroquiExtracaoState extends State<CroquiExtracao> {
  double? _aspectRatio;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolverImagem();
  }

  @override
  void didUpdateWidget(covariant CroquiExtracao oldWidget) {
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
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Planta não disponível', style: TextStyle(color: Colors.grey))),
      );
    }

    if (_aspectRatio == null) {
      return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
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
                      children: widget.pontosOrdenados.asMap().entries.map((entry) {
                        final numero = entry.key + 1;
                        final ponto = entry.value;
                        const diametro = 32.0;
                        return Positioned(
                          left: (ponto.posX * w) - (diametro / 2),
                          top: (ponto.posY * h) - (diametro / 2),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.onTapPonto == null ? null : () => widget.onTapPonto!(ponto),
                            child: Container(
                              width: diametro,
                              height: diametro,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: Center(
                                child: Text('$numero', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
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
