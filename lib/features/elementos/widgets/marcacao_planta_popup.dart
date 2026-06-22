import 'dart:io';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🔥 Novo Import
import 'package:pdfx/pdfx.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart'; // 🔥 Novo Import
import 'package:diavicon/features/elementos/providers/elemento_provider.dart'; // 🔥 Novo Import
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Marcação de um elemento sobre a planta.
class MarcacaoPlanta {
  const MarcacaoPlanta({
    required this.x,
    required this.y,
    required this.plantaId,
    this.tipoMarcacao = 'Retângulo', 
    this.numero = 1,
    this.thumbnailBytes,
    this.nomeElemento,
  });

  final double x; 
  final double y; 
  final String plantaId;
  final String tipoMarcacao;
  final int numero;
  final Uint8List? thumbnailBytes;
  final String? nomeElemento;

  MarcacaoPlanta copyWith({double? x, double? y, String? plantaId, String? tipoMarcacao, int? numero, Uint8List? thumbnailBytes}) {
    return MarcacaoPlanta(
      x: x ?? this.x,
      y: y ?? this.y,
      plantaId: plantaId ?? this.plantaId,
      tipoMarcacao: tipoMarcacao ?? this.tipoMarcacao,
      numero: numero ?? this.numero,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    );
  }

  Map<String, dynamic> toPosicaoMap() => <String, dynamic>{
        'posicao_x': x,
        'posicao_y': y,
        'planta_id': plantaId,
        'tipo_marcacao': tipoMarcacao, 
      };
}

/// Pino Inteligente que muda de formato e mostra o nome
class PinoDinamico extends StatelessWidget {
  const PinoDinamico({super.key, required this.tipoMarcacao, this.nomeElemento, this.numero = 1});

  final String tipoMarcacao;
  final String? nomeElemento;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final tipo = tipoMarcacao.toLowerCase();
    final isCirculo = tipo == 'círculo';
    final isLinha = tipo == 'linha';
    final isPonto = tipo == 'ponto';

    double largura = 26;
    double altura = 26;
    if (isLinha) { largura = 50; altura = 12; } 
    if (isPonto) { largura = 16; altura = 16; } 

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: largura,
          height: altura,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            shape: (isCirculo || isPonto) ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: (!isCirculo && !isPonto) ? BorderRadius.circular(4) : null,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2))],
          ),
          child: (nomeElemento == null && !isPonto && !isLinha) 
              ? Text('$numero', style: GoogleFonts.lato(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
              : null,
        ),
        
        if (nomeElemento != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
            child: Text(nomeElemento!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }
}

/// Abre o popup de marcação em planta.
Future<MarcacaoPlanta?> showMarcacaoPlantaPopup(
  BuildContext context, {
  required String arquivoUrl,
  required String plantaId,
  String? estruturaId, // 🔥 NOVO
  MarcacaoPlanta? inicial,
  int numero = 1,
  String? nomeElemento, 
}) {
  return showDialog<MarcacaoPlanta>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => MarcacaoPlantaPopup(
      arquivoUrl: arquivoUrl,
      plantaId: plantaId,
      estruturaId: estruturaId, // 🔥 REPASSA
      marcacaoInicial: inicial,
      numero: numero,
      nomeElemento: nomeElemento, 
    ),
  );
}

class MarcacaoPlantaPopup extends StatefulWidget {
  const MarcacaoPlantaPopup({
    super.key,
    required this.arquivoUrl,
    required this.plantaId,
    this.estruturaId, // 🔥 NOVO
    this.marcacaoInicial,
    this.numero = 1,
    this.nomeElemento, 
  });

  final String arquivoUrl;
  final String plantaId;
  final String? estruturaId; 
  final MarcacaoPlanta? marcacaoInicial;
  final int numero;
  final String? nomeElemento; 

  @override
  State<MarcacaoPlantaPopup> createState() => _MarcacaoPlantaPopupState();
}

class _MarcacaoPlantaPopupState extends State<MarcacaoPlantaPopup> {
  Offset? _ponto;
  String _tipoMarcacaoSelecionado = 'Retângulo'; 
  Uint8List? _imagemRenderizada; 

  int get _numero => widget.marcacaoInicial?.numero ?? widget.numero;

  @override
  void initState() {
    super.initState();
    final inicial = widget.marcacaoInicial;
    if (inicial != null && inicial.plantaId == widget.plantaId) {
      _ponto = Offset(inicial.x, inicial.y);
      _tipoMarcacaoSelecionado = inicial.tipoMarcacao;
      _imagemRenderizada = inicial.thumbnailBytes;
    }
  }

  bool get _podeSalvar => _ponto != null;

  void _salvar() {
    final ponto = _ponto;
    if (ponto == null) return;
    Navigator.of(context).pop(
      MarcacaoPlanta(
        x: ponto.dx, 
        y: ponto.dy, 
        plantaId: widget.plantaId, 
        tipoMarcacao: _tipoMarcacaoSelecionado, 
        numero: _numero,
        thumbnailBytes: _imagemRenderizada, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final largura = (mediaQuery.size.width - 32).clamp(280.0, 350.0).toDouble();
    final alturaMaximaPlanta = mediaQuery.size.height * 0.50;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: largura,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _CloseButton(onPressed: () => Navigator.of(context).maybePop()),
                ),
                Text(
                  'Selecione o local na planta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 8),
                
                Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tipoMarcacaoSelecionado,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3E3E3D)),
                      style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 18, fontWeight: FontWeight.w500),
                      items: ['Retângulo', 'Círculo', 'Linha', 'Ponto']
                          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _tipoMarcacaoSelecionado = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  color: const Color(0xFFD9D9D9),
                  height: alturaMaximaPlanta,
                  child: _PlantaInterativa(
                    arquivoUrl: widget.arquivoUrl,
                    plantaId: widget.plantaId,
                    estruturaId: widget.estruturaId, // 🔥 NOVO
                    numero: _numero,
                    ponto: _ponto,
                    tipoMarcacao: _tipoMarcacaoSelecionado, 
                    nomeElemento: widget.nomeElemento,      
                    onTap: (relativo) => setState(() => _ponto = relativo),
                    onImageReady: (bytes) {
                      if (mounted) setState(() => _imagemRenderizada = bytes);
                    },
                  ),
                ),
                
                const SizedBox(height: 18),
                Center(
                  child: _SalvarButton(onPressed: _podeSalvar ? _salvar : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 ALTERADO: Mudou para ConsumerStatefulWidget para escutar o banco
class _PlantaInterativa extends ConsumerStatefulWidget {
  const _PlantaInterativa({
    required this.arquivoUrl,
    required this.plantaId,
    this.estruturaId,
    required this.numero,
    required this.ponto,
    required this.tipoMarcacao,
    this.nomeElemento,
    required this.onTap,
    this.onImageReady,
  });

  final String arquivoUrl;
  final String plantaId;
  final String? estruturaId;
  final int numero;
  final Offset? ponto;
  final String tipoMarcacao; 
  final String? nomeElemento; 
  final ValueChanged<Offset> onTap;
  final ValueChanged<Uint8List>? onImageReady;

  @override
  ConsumerState<_PlantaInterativa> createState() => _PlantaInterativaState();
}

class _PlantaInterativaState extends ConsumerState<_PlantaInterativa> {
  bool _isPdf = false;
  bool _isLoadingPdf = false;
  Uint8List? _pdfImageBytes;
  String? _errorMessage; 

  @override
  void initState() {
    super.initState();
    _verificarECarregarPdf();
  }

  Future<void> _verificarECarregarPdf() async {
    final urlLower = widget.arquivoUrl.toLowerCase();
    if (urlLower.contains('.pdf')) {
      setState(() { _isPdf = true; _isLoadingPdf = true; _errorMessage = null; });
      try {
        final request = await HttpClient().getUrl(Uri.parse(widget.arquivoUrl));
        final response = await request.close();
        if (response.statusCode != 200) throw Exception('Erro no download: ${response.statusCode}');
        final pdfBytes = await consolidateHttpClientResponseBytes(response);
        final document = await PdfDocument.openData(pdfBytes);
        final page = await document.getPage(1);
        
        double renderWidth = page.width; double renderHeight = page.height;
        if (renderWidth < 1000) { renderWidth *= 2.0; renderHeight *= 2.0; }
        const maxDim = 2500.0;
        if (renderWidth > maxDim || renderHeight > maxDim) {
          final proporcao = renderWidth / renderHeight;
          if (renderWidth > renderHeight) { renderWidth = maxDim; renderHeight = maxDim / proporcao; } 
          else { renderHeight = maxDim; renderWidth = maxDim * proporcao; }
        }

        final pageImage = await page.render(width: renderWidth, height: renderHeight, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
        if (pageImage != null && mounted) {
          setState(() => _pdfImageBytes = pageImage.bytes);
          widget.onImageReady?.call(pageImage.bytes); 
        } else { throw Exception('A renderização retornou nulo'); }
        await page.close(); await document.close();
      } catch (e) {
        debugPrint('Erro ao carregar PDF: $e');
        if (mounted) setState(() => _errorMessage = e.toString()); 
      } finally {
        if (mounted) setState(() => _isLoadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BUSCA INTELIGENTE: Pega os pinos que já existem nesta planta
    List<ElementoModel> pinosVizinhos = [];
    if (widget.estruturaId != null) {
      final elementosAsync = ref.watch(elementosPorEstruturaProvider(widget.estruturaId!));
      pinosVizinhos = elementosAsync.value?.where((el) => 
        el.plantaId == widget.plantaId && 
        el.posicaoX != null && 
        el.posicaoY != null
      ).toList() ?? [];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          constrained: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final local = details.localPosition;
              widget.onTap(Offset(
                (local.dx / constraints.maxWidth).clamp(0.0, 1.0),
                (local.dy / constraints.maxHeight).clamp(0.0, 1.0),
              ));
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isPdf) ...[
                  if (_isLoadingPdf) const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else if (_pdfImageBytes != null) Image.memory(_pdfImageBytes!, fit: BoxFit.contain)
                  else if (_errorMessage != null) Center(child: Text('Falha ao carregar planta:\n$_errorMessage', style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center))
                  else const Center(child: Icon(Icons.picture_as_pdf, size: 50, color: Colors.grey))
                ] else ...[
                  Image.network(widget.arquivoUrl, fit: BoxFit.contain),
                ],

                // 🔥 CAMADA NOVA: Desenha os pinos que já existem (com opacidade reduzida)
                ...pinosVizinhos.map((el) {
                  final xAbs = el.posicaoX! * constraints.maxWidth;
                  final yAbs = el.posicaoY! * constraints.maxHeight;

                  final tipo = (el.tipoMarcacao ?? 'Retângulo').toLowerCase();
                  final isLinha = tipo == 'linha';
                  final isPonto = tipo == 'ponto';
                  final wPino = isLinha ? 50.0 : (isPonto ? 16.0 : 26.0);
                  final hPino = isLinha ? 12.0 : (isPonto ? 16.0 : 26.0);

                  return Positioned(
                    left: xAbs - (wPino / 2),
                    top: yAbs - (hPino / 2),
                    child: Opacity(
                      opacity: 0.45, // 🔥 Transparente para indicar que é do "fundo"
                      child: PinoDinamico(
                        tipoMarcacao: el.tipoMarcacao ?? 'Retângulo',
                        nomeElemento: el.nome,
                      ),
                    ),
                  );
                }),

                // O Pino Atual ativo (100% visível)
                if (widget.ponto != null) ...[
                  () {
                    final tipo = widget.tipoMarcacao.toLowerCase();
                    final isLinha = tipo == 'linha';
                    final isPonto = tipo == 'ponto';
                    final wPino = isLinha ? 50.0 : (isPonto ? 16.0 : 26.0);
                    final hPino = isLinha ? 12.0 : (isPonto ? 16.0 : 26.0);

                    return Positioned(
                      left: (widget.ponto!.dx * constraints.maxWidth) - (wPino / 2),
                      top: (widget.ponto!.dy * constraints.maxHeight) - (hPino / 2),
                      child: PinoDinamico(
                        tipoMarcacao: widget.tipoMarcacao, 
                        nomeElemento: widget.nomeElemento,
                        numero: widget.numero
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SalvarButton extends StatelessWidget {
  const _SalvarButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null ? const [] : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.30), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5), foregroundColor: Colors.white, disabledForegroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        child: Text('Salvar', style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400, height: 1)),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(Icons.close, color: const Color(0xFF626365).withValues(alpha: 0.40), size: 24),
      ),
    );
  }
}