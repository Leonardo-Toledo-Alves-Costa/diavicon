import 'dart:io';
import 'package:diavicon/core/constants/app_text_styles.dart';
import 'package:diavicon/features/elementos/providers/info_planejamento_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/features/elementos/widgets/marcacao_planta_popup.dart';


class LocalRegiaoResult {
  final double x, y, largura, altura, rotacao;
  final String cor, tipo; 
  LocalRegiaoResult({required this.x, required this.y, required this.largura, required this.altura, required this.rotacao, required this.cor, required this.tipo});
}

class SelecionarLocalRegiaoModal extends ConsumerStatefulWidget {
  final String estruturaId, plantaId, empresaId, arquivoUrl;
  final int proximoNumero;
  final double? initialX, initialY, initialLargura, initialAltura, initialRotacao;
  final String? initialCor, initialTipo;

  const SelecionarLocalRegiaoModal({
    super.key, required this.estruturaId, required this.plantaId, required this.empresaId, required this.arquivoUrl, required this.proximoNumero,
    this.initialX, this.initialY, this.initialLargura, this.initialAltura, this.initialRotacao, this.initialCor, this.initialTipo,
  });

  @override
  ConsumerState<SelecionarLocalRegiaoModal> createState() => _SelecionarLocalRegiaoModalState();
}

class _SelecionarLocalRegiaoModalState extends ConsumerState<SelecionarLocalRegiaoModal> {
  final TransformationController _transformationController = TransformationController();
  bool _isPdf = false, _isLoading = false;
  Uint8List? _imageBytes;
  Offset? _pontoSelecionado;
  
  String _tipoMarcacao = 'Círculo';
  double _largura = 0.05, _altura = 0.05, _rotacao = 0.0;
  
  String _corSelecionada = '#FF9800'; 
  final List<String> _coresSalvas = ['#FF9800', '#2196F3', '#F44336']; 

  @override
  void initState() { 
    super.initState(); _carregarMidia(); 
    if (widget.initialX != null && widget.initialY != null) _pontoSelecionado = Offset(widget.initialX!, widget.initialY!);
    if (widget.initialTipo != null) _tipoMarcacao = widget.initialTipo!;
    if (widget.initialLargura != null) _largura = widget.initialLargura!;
    if (widget.initialAltura != null) _altura = widget.initialAltura!;
    if (widget.initialRotacao != null) _rotacao = widget.initialRotacao!;
    if (widget.initialCor != null) {
      _corSelecionada = widget.initialCor!;
      if (!_coresSalvas.contains(_corSelecionada)) _coresSalvas.add(_corSelecionada);
    }
  }

  Future<void> _carregarMidia() async {
    final urlLower = widget.arquivoUrl.toLowerCase();
    if (urlLower.contains('.pdf')) {
      setState(() { _isPdf = true; _isLoading = true; });
      try {
        final req = await HttpClient().getUrl(Uri.parse(widget.arquivoUrl));
        final doc = await PdfDocument.openData(await consolidateHttpClientResponseBytes(await req.close()));
        final page = await doc.getPage(1);
        double w = page.width; double h = page.height;
        if (w < 1000) { w *= 2.0; h *= 2.0; }
        const maxDim = 2500.0;
        if (w > maxDim || h > maxDim) {
          final prop = w / h;
          if (w > h) { w = maxDim; h = maxDim / prop; } else { h = maxDim; w = maxDim * prop; }
        }
        final pageImg = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
        if (pageImg != null && mounted) setState(() => _imageBytes = pageImg.bytes);
        await page.close(); await doc.close();
      } catch (e) { debugPrint('Erro PDF: $e'); } finally { if (mounted) setState(() => _isLoading = false); }
    }
  }

  Color _hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xff')));

  void _abrirColorPicker() {
    Color corTemp = _hexToColor(_corSelecionada);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha a cor', style: AppTextStyles.tituloPrincipal),
        content: SingleChildScrollView(child: ColorPicker(pickerColor: corTemp, onColorChanged: (Color c) => corTemp = c, enableAlpha: false, labelTypes: const [])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () { setState(() { _corSelecionada = '#${corTemp.toARGB32().toRadixString(16).substring(2).toUpperCase()}'; if (!_coresSalvas.contains(_corSelecionada)) _coresSalvas.add(_corSelecionada); }); Navigator.pop(context); },
            child: const Text('Salvar', style: AppTextStyles.corpoDestaqueBranco),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regioesAsync = ref.watch(regioesEnsaioProvider(RegioesFiltro(plantaId: widget.plantaId, empresaId: widget.empresaId)));

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
                Expanded(child: Text('Selecione o local', style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900))),
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
                    transformationController: _transformationController, minScale: 1.0, maxScale: 5.0,
                    child: Center(
                      child: Stack(
                        children: [
                          _isPdf ? (_imageBytes != null ? Image.memory(_imageBytes!) : const SizedBox()) : Image.network(widget.arquivoUrl),
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth; final h = constraints.maxHeight;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent, 
                                        onTapUp: (details) => setState(() => _pontoSelecionado = Offset((details.localPosition.dx / w).clamp(0.0, 1.0), (details.localPosition.dy / h).clamp(0.0, 1.0))),
                                      ),
                                    ),
                                      
                                    if (regioesAsync.value != null)
                                      ...regioesAsync.value!.map((reg) {
                                        final cx = reg.posicaoX * w; final cy = reg.posicaoY * h;
                                        final wPino = reg.marcacaoLargura * w; final hPino = reg.marcacaoAltura * h;
                                        final corAntiga = Color(int.parse(reg.corMarcacao.replaceFirst('#', '0xff')));
                                        return Positioned(
                                          left: cx - (wPino / 2), top: cy - (hPino / 2),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Opacity(opacity: 0.5, child: PinoDinamico(tipoMarcacao: reg.tipoMarcacao, largura: wPino, altura: hPino, rotacao: reg.marcacaoRotacao, corBase: corAntiga, mostrarNumero: false)), // 🔥 Corrigido aqui
                                              Opacity(opacity: 0.8, child: Text(reg.numero.toString(), style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                            ]
                                          )
                                        );
                                      }),

                                    if (_pontoSelecionado != null)
                                      Positioned(
                                        left: (_pontoSelecionado!.dx * w) - ((_largura * w) / 2), 
                                        top: (_pontoSelecionado!.dy * h) - ((_altura * h) / 2),
                                        child: GestureDetector(
                                          onPanUpdate: (details) => setState(() => _pontoSelecionado = Offset((_pontoSelecionado!.dx + (details.delta.dx / w)).clamp(0.0, 1.0), (_pontoSelecionado!.dy + (details.delta.dy / h)).clamp(0.0, 1.0))),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              PinoDinamico(tipoMarcacao: _tipoMarcacao, largura: _largura * w, altura: _altura * h, rotacao: _rotacao, corBase: _hexToColor(_corSelecionada).withValues(alpha: 0.85), mostrarNumero: false), // 🔥 E aqui
                                              Text(widget.proximoNumero.toString(), style: GoogleFonts.lato(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black45, blurRadius: 2)])),
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
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ..._coresSalvas.map((cor) => GestureDetector(
                              onTap: () => setState(() => _corSelecionada = cor),
                              child: Container(margin: const EdgeInsets.only(right: 12), width: 32, height: 32, decoration: BoxDecoration(color: _hexToColor(cor), shape: BoxShape.circle, border: _corSelecionada == cor ? Border.all(color: AppColors.greyDarkest, width: 2.5) : Border.all(color: Colors.black12))),
                            )),
                            GestureDetector(onTap: _abrirColorPicker, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.inputBorder, width: 1.5)), child: const Icon(Icons.colorize, size: 16, color: AppColors.greyMedium))),
                          ],
                        ),
                      )),
                      const SizedBox(width: 16), 
                      ToggleButtons(
                        isSelected: [_tipoMarcacao == 'Círculo', _tipoMarcacao == 'Retângulo'],
                        onPressed: (idx) => setState(() {
                          _tipoMarcacao = idx == 0 ? 'Círculo' : 'Retângulo';
                          if (_tipoMarcacao == 'Círculo') {
                            if (_largura > 0.80) _largura = 0.80;
                            _altura = _largura;
                          }
                        }),
                        borderRadius: BorderRadius.circular(8),
                        constraints: const BoxConstraints(minHeight: 36, minWidth: 40),
                        children: const [Icon(Icons.circle_outlined, size: 20), Icon(Icons.crop_square, size: 20)],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_tipoMarcacao == 'Círculo') ...[
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tamanho da Marcação', style: GoogleFonts.lato(fontSize: 12)),
                          Slider(value: _largura, min: 0.02, max: 0.80, activeColor: _hexToColor(_corSelecionada), onChanged: (v) => setState(() { _largura = v; _altura = v; })),
                        ])),
                        CompactButton(text: 'Próximo', width: 100, backgroundColor: _pontoSelecionado == null ? AppColors.greyLight : AppColors.primary, onPressed: () { if (_pontoSelecionado != null) Navigator.pop(context, LocalRegiaoResult(x: _pontoSelecionado!.dx, y: _pontoSelecionado!.dy, largura: _largura, altura: _largura, rotacao: 0.0, cor: _corSelecionada, tipo: _tipoMarcacao)); }),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Largura', style: GoogleFonts.lato(fontSize: 12)),
                          Slider(value: _largura, min: 0.02, max: 0.80, activeColor: _hexToColor(_corSelecionada), onChanged: (v) => setState(() => _largura = v)),
                        ])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Altura', style: GoogleFonts.lato(fontSize: 12)),
                          Slider(value: _altura, min: 0.02, max: 0.80, activeColor: _hexToColor(_corSelecionada), onChanged: (v) => setState(() => _altura = v)),
                        ])),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Rotação', style: GoogleFonts.lato(fontSize: 12)),
                          Slider(value: _rotacao, min: 0.0, max: 360.0, activeColor: _hexToColor(_corSelecionada), onChanged: (v) => setState(() => _rotacao = v)),
                        ])),
                        CompactButton(text: 'Próximo', width: 100, backgroundColor: _pontoSelecionado == null ? AppColors.greyLight : AppColors.primary, onPressed: () { if (_pontoSelecionado != null) Navigator.pop(context, LocalRegiaoResult(x: _pontoSelecionado!.dx, y: _pontoSelecionado!.dy, largura: _largura, altura: _altura, rotacao: _rotacao, cor: _corSelecionada, tipo: _tipoMarcacao)); }),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}