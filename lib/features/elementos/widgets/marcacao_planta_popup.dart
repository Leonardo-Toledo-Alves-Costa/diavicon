import 'dart:io';
import 'dart:typed_data';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as InternetFile;
import 'package:pdfx/pdfx.dart';

/// Marcação de um elemento sobre a planta.
class MarcacaoPlanta {
  const MarcacaoPlanta({
    required this.x,
    required this.y,
    required this.plantaId,
    this.tipoMarcacao = 'Retângulo', // 🔥 Alterado para tipoMarcacao
    this.numero = 1,
  });

  final double x; // 0..1
  final double y; // 0..1
  final String plantaId;
  final String tipoMarcacao;
  final int numero;

  MarcacaoPlanta copyWith({double? x, double? y, String? plantaId, String? tipoMarcacao, int? numero}) {
    return MarcacaoPlanta(
      x: x ?? this.x,
      y: y ?? this.y,
      plantaId: plantaId ?? this.plantaId,
      tipoMarcacao: tipoMarcacao ?? this.tipoMarcacao,
      numero: numero ?? this.numero,
    );
  }

  Map<String, dynamic> toPosicaoMap() => <String, dynamic>{
        'posicao_x': x,
        'posicao_y': y,
        'planta_id': plantaId,
        'tipo_marcacao': tipoMarcacao, // 🔥 Alinhado com o banco de dados
      };
}

/// Bolinha laranja numerada que representa a marcação na planta.
class MarcacaoBolinha extends StatelessWidget {
  const MarcacaoBolinha({super.key, required this.numero, this.tamanho = 26});

  final int numero;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$numero',
        style: GoogleFonts.lato(
          color: Colors.white,
          fontSize: tamanho * 0.46,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

/// Abre o popup de marcação em planta.
Future<MarcacaoPlanta?> showMarcacaoPlantaPopup(
  BuildContext context, {
  required String arquivoUrl,
  required String plantaId,
  MarcacaoPlanta? inicial,
  int numero = 1,
}) {
  return showDialog<MarcacaoPlanta>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => MarcacaoPlantaPopup(
      arquivoUrl: arquivoUrl,
      plantaId: plantaId,
      marcacaoInicial: inicial,
      numero: numero,
    ),
  );
}

class MarcacaoPlantaPopup extends StatefulWidget {
  const MarcacaoPlantaPopup({
    super.key,
    required this.arquivoUrl,
    required this.plantaId,
    this.marcacaoInicial,
    this.numero = 1,
  });

  final String arquivoUrl;
  final String plantaId;
  final MarcacaoPlanta? marcacaoInicial;
  final int numero;

  @override
  State<MarcacaoPlantaPopup> createState() => _MarcacaoPlantaPopupState();
}

class _MarcacaoPlantaPopupState extends State<MarcacaoPlantaPopup> {
  Offset? _ponto;
  String _tipoMarcacaoSelecionado = 'Retângulo'; // 🔥 Alterado

  int get _numero => widget.marcacaoInicial?.numero ?? widget.numero;

  @override
  void initState() {
    super.initState();
    final inicial = widget.marcacaoInicial;
    if (inicial != null && inicial.plantaId == widget.plantaId) {
      _ponto = Offset(inicial.x, inicial.y);
      _tipoMarcacaoSelecionado = inicial.tipoMarcacao;
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
        tipoMarcacao: _tipoMarcacaoSelecionado, // 🔥 Alterado
        numero: _numero,
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
                
                // 🔥 Dropdown com o tipo de marcação
                Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tipoMarcacaoSelecionado,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF3E3E3D)),
                      style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 18, fontWeight: FontWeight.w500),
                      items: ['Retângulo', 'Círculo', 'Ponto']
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
                    numero: _numero,
                    ponto: _ponto,
                    onTap: (relativo) => setState(() => _ponto = relativo),
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

class _PlantaInterativa extends StatefulWidget {
  const _PlantaInterativa({
    required this.arquivoUrl,
    required this.numero,
    required this.ponto,
    required this.onTap,
  });

  final String arquivoUrl;
  final int numero;
  final Offset? ponto;
  final ValueChanged<Offset> onTap;

  @override
  State<_PlantaInterativa> createState() => _PlantaInterativaState();
}

class _PlantaInterativaState extends State<_PlantaInterativa> {
  bool _isPdf = false;
  bool _isLoadingPdf = false;
  Uint8List? _pdfImageBytes;

  @override
  void initState() {
    super.initState();
    _verificarECarregarPdf();
  }

  Future<void> _verificarECarregarPdf() async {
    final urlLower = widget.arquivoUrl.toLowerCase();
    if (urlLower.contains('.pdf')) {
      setState(() {
        _isPdf = true;
        _isLoadingPdf = true;
      });

      try {
        // 🔥 1. Faz o download nativo via dart:io (Adeus internet_file!)
        final request = await HttpClient().getUrl(Uri.parse(widget.arquivoUrl));
        final response = await request.close();
        final pdfBytes = await consolidateHttpClientResponseBytes(response);

        // 2. Abre o documento PDF
        final document = await PdfDocument.openData(pdfBytes);
        
        // 3. Pega a página 1 da planta
        final page = await document.getPage(1);
        
        // 4. "Bate uma foto" da página (renderiza como imagem)
        final pageImage = await page.render(
          width: page.width * 2.5, 
          height: page.height * 2.5,
          format: PdfPageImageFormat.jpeg,
        );

        if (pageImage != null && mounted) {
          setState(() => _pdfImageBytes = pageImage.bytes);
        }

        await page.close();
        await document.close();
      } catch (e) {
        debugPrint('Erro ao carregar PDF: $e');
      } finally {
        if (mounted) setState(() => _isLoadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // 🔥 LÓGICA DE RENDERIZAÇÃO INTELIGENTE
                if (_isPdf) ...[
                  if (_isLoadingPdf)
                    const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  else if (_pdfImageBytes != null)
                    Image.memory(_pdfImageBytes!, fit: BoxFit.contain)
                  else
                    const Center(child: Icon(Icons.picture_as_pdf, size: 50, color: Colors.grey))
                ] else ...[
                  Image.network(
                    widget.arquivoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey));
                    },
                  ),
                ],

                if (widget.ponto != null)
                  Positioned(
                    left: (widget.ponto!.dx * constraints.maxWidth) - 13,
                    top: (widget.ponto!.dy * constraints.maxHeight) - 13,
                    child: MarcacaoBolinha(numero: widget.numero),
                  ),
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
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
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