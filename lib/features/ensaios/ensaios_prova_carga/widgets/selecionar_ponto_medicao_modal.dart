import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../elementos/widgets/marcacao_planta_popup.dart' show PinoDinamico;
import '../models/ponto_medicao_model.dart';

class SelecaoPontoMedicaoResult {
  final double x;
  final double y;
  final double tamanho;
  SelecaoPontoMedicaoResult({required this.x, required this.y, required this.tamanho});
}

/// Marca a posição (círculo numerado) de um ponto de medição na planta,
/// mostrando os demais pontos já marcados como referência. Espelha o
/// `SelecionarLocalRegiaoModal` (ramo Círculo), sem seletor de cor/forma.
class SelecionarPontoMedicaoModal extends StatefulWidget {
  final String plantaUrl;
  final int numeroVisual;
  final List<PontoMedicaoModel> pontosExistentes;
  final double? initialX;
  final double? initialY;
  final double? initialTamanho;

  const SelecionarPontoMedicaoModal({
    super.key,
    required this.plantaUrl,
    required this.numeroVisual,
    required this.pontosExistentes,
    this.initialX,
    this.initialY,
    this.initialTamanho,
  });

  @override
  State<SelecionarPontoMedicaoModal> createState() => _SelecionarPontoMedicaoModalState();
}

class _SelecionarPontoMedicaoModalState extends State<SelecionarPontoMedicaoModal> {
  bool _isPdf = false;
  bool _isLoading = false;
  Uint8List? _imageBytes;
  Offset? _pontoSelecionado;
  double _tamanho = 0.05;

  @override
  void initState() {
    super.initState();
    if (widget.initialX != null && widget.initialY != null) {
      _pontoSelecionado = Offset(widget.initialX!, widget.initialY!);
    }
    _tamanho = widget.initialTamanho ?? 0.05;
    _carregarMidia();
  }

  Future<void> _carregarMidia() async {
    if (widget.plantaUrl.toLowerCase().contains('.pdf')) {
      setState(() {
        _isPdf = true;
        _isLoading = true;
      });
      try {
        final req = await HttpClient().getUrl(Uri.parse(await StorageUrls.assinar(widget.plantaUrl)));
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
        if (pageImg != null && mounted) setState(() => _imageBytes = pageImg.bytes);
        await page.close();
        await doc.close();
      } catch (e) {
        debugPrint('Erro PDF: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      height: MediaQuery.of(context).size.height * 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Selecione o local na planta', style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900)),
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9))),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Center(
                        child: Stack(
                          children: [
                            _isPdf ? (_imageBytes != null ? Image.memory(_imageBytes!) : const SizedBox()) : ImagemStorage.network(widget.plantaUrl),
                            Positioned.fill(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final w = constraints.maxWidth;
                                  final h = constraints.maxHeight;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned.fill(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTapUp: (details) => setState(() => _pontoSelecionado = Offset(
                                                (details.localPosition.dx / w).clamp(0.0, 1.0),
                                                (details.localPosition.dy / h).clamp(0.0, 1.0),
                                              )),
                                        ),
                                      ),
                                      ...widget.pontosExistentes.map((ponto) {
                                        final numero = ponto.nome.replaceAll(RegExp(r'[^0-9]'), '');
                                        final tam = ponto.tamanho * w;
                                        return Positioned(
                                          left: (ponto.x * w) - (tam / 2),
                                          top: (ponto.y * h) - (tam / 2),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Opacity(
                                                opacity: 0.5,
                                                child: PinoDinamico(tipoMarcacao: 'Círculo', largura: tam, altura: tam, corBase: AppColors.primary),
                                              ),
                                              Opacity(
                                                opacity: 0.8,
                                                child: Text(numero, style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      if (_pontoSelecionado != null)
                                        Positioned(
                                          left: (_pontoSelecionado!.dx * w) - ((_tamanho * w) / 2),
                                          top: (_pontoSelecionado!.dy * h) - ((_tamanho * h) / 2),
                                          child: GestureDetector(
                                            onPanUpdate: (details) => setState(() => _pontoSelecionado = Offset(
                                                  (_pontoSelecionado!.dx + (details.delta.dx / w)).clamp(0.0, 1.0),
                                                  (_pontoSelecionado!.dy + (details.delta.dy / h)).clamp(0.0, 1.0),
                                                )),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                PinoDinamico(
                                                  tipoMarcacao: 'Círculo',
                                                  largura: _tamanho * w,
                                                  altura: _tamanho * h,
                                                  corBase: const Color(0xFF238E5A),
                                                ),
                                                Text(
                                                  '${widget.numeroVisual}',
                                                  style: GoogleFonts.lato(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black45, blurRadius: 2)]),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tamanho da Marcação', style: GoogleFonts.lato(fontSize: 12)),
                        Slider(
                          value: _tamanho,
                          min: 0.02,
                          max: 0.3,
                          activeColor: const Color(0xFF238E5A),
                          onChanged: (v) => setState(() => _tamanho = v),
                        ),
                      ],
                    ),
                  ),
                  CompactButton(
                    text: 'Próximo',
                    width: 100,
                    backgroundColor: _pontoSelecionado == null ? AppColors.greyLight : AppColors.primary,
                    onPressed: () {
                      if (_pontoSelecionado == null) return;
                      Navigator.pop(
                        context,
                        SelecaoPontoMedicaoResult(x: _pontoSelecionado!.dx, y: _pontoSelecionado!.dy, tamanho: _tamanho),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
