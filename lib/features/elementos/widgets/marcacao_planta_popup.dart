import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'package:pdfx/pdfx.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart'; 
import 'package:diavicon/features/elementos/providers/elemento_provider.dart'; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ModoFerramenta { navegar, mover, redimensionar }

class MarcacaoPlanta {
  const MarcacaoPlanta({
    required this.x, required this.y, required this.plantaId,
    this.tipoMarcacao = 'Retângulo', this.numero = 1,
    this.thumbnailBytes, this.nomeElemento,
    this.largura = 0.08, this.altura = 0.06,  
    this.rotacao = 0.0, // 🔥 NOVO: Rotação em graus
  });

  final double x, y, largura, altura, rotacao;
  final String plantaId, tipoMarcacao;
  final int numero;
  final Uint8List? thumbnailBytes;
  final String? nomeElemento;

  MarcacaoPlanta copyWith({
    double? x, double? y, String? plantaId, String? tipoMarcacao, 
    int? numero, Uint8List? thumbnailBytes, double? largura, double? altura, double? rotacao,
  }) {
    return MarcacaoPlanta(
      x: x ?? this.x, y: y ?? this.y, plantaId: plantaId ?? this.plantaId,
      tipoMarcacao: tipoMarcacao ?? this.tipoMarcacao, numero: numero ?? this.numero,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      largura: largura ?? this.largura, altura: altura ?? this.altura,
      rotacao: rotacao ?? this.rotacao,
    );
  }

  Map<String, dynamic> toPosicaoMap() => <String, dynamic>{
        'posicao_x': x, 'posicao_y': y, 'planta_id': plantaId,
        'tipo_marcacao': tipoMarcacao, 'marcacao_largura': largura, 'marcacao_altura': altura,
        'marcacao_rotacao': rotacao, 
      };
}

class PinoDinamico extends StatelessWidget {
  const PinoDinamico({super.key, required this.tipoMarcacao, this.nomeElemento, this.numero = 1, this.largura, this.altura, this.ocultarTexto = false, this.rotacao = 0.0});

  final String tipoMarcacao;
  final String? nomeElemento;
  final int numero;
  final double? largura, altura;
  final bool ocultarTexto;
  final double rotacao; // 🔥 NOVO

  @override
  Widget build(BuildContext context) {
    final tipo = tipoMarcacao.toLowerCase();
    final isCirculo = tipo == 'círculo' || tipo == 'ponto';
    final isLinha = tipo == 'linha';

    double larguraPino = largura ?? 26.0;
    double alturaPino = altura ?? 26.0;
    
    if (largura == null && altura == null) {
      if (isLinha) { larguraPino = 50; alturaPino = 12; } 
      if (tipo == 'ponto') { larguraPino = 16; alturaPino = 16; } 
    } else if (isCirculo) { alturaPino = larguraPino; }

    return Stack(
      clipBehavior: Clip.none, alignment: Alignment.center,
      children: [
        //  Transform.rotate gira apenas a figura
        Transform.rotate(
          angle: rotacao * (math.pi / 180), // Converte de graus para radianos
          child: Container(
            width: larguraPino, height: alturaPino, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.45),
              shape: isCirculo ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: (!isCirculo && !isLinha) ? BorderRadius.circular(4) : null,
              border: Border.all(color: Colors.orange.shade900, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: (!ocultarTexto && nomeElemento == null && tipo != 'ponto' && !isLinha) 
                ? Transform.rotate( // Desfaz a rotação pro número ficar reto
                    angle: -rotacao * (math.pi / 180),
                    child: Text('$numero', style: GoogleFonts.lato(color: Colors.orange.shade900, fontSize: larguraPino > 24 ? 13 : 9, fontWeight: FontWeight.w900)),
                  )
                : null,
          ),
        ),
        // O texto do nome do elemento fica de fora do Transform para não girar junto
        if (!ocultarTexto && nomeElemento != null)
          Positioned(
            top: -24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(4)),
              child: Text(nomeElemento!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          )
      ],
    );
  }
}

Future<MarcacaoPlanta?> showMarcacaoPlantaPopup(
  BuildContext context, {
  required String arquivoUrl, required String plantaId, String? estruturaId, 
  MarcacaoPlanta? inicial, int numero = 1, String? nomeElemento, 
}) {
  return showDialog<MarcacaoPlanta>(
    context: context, barrierColor: Colors.black.withOpacity(0.5),
    builder: (_) => MarcacaoPlantaPopup(
      arquivoUrl: arquivoUrl, plantaId: plantaId, estruturaId: estruturaId,
      marcacaoInicial: inicial, numero: numero, nomeElemento: nomeElemento, 
    ),
  );
}

class MarcacaoPlantaPopup extends StatefulWidget {
  const MarcacaoPlantaPopup({
    super.key, required this.arquivoUrl, required this.plantaId, this.estruturaId, 
    this.marcacaoInicial, this.numero = 1, this.nomeElemento, 
  });
  final String arquivoUrl, plantaId;
  final String? estruturaId, nomeElemento; 
  final MarcacaoPlanta? marcacaoInicial;
  final int numero;

  @override
  State<MarcacaoPlantaPopup> createState() => _MarcacaoPlantaPopupState();
}

class _MarcacaoPlantaPopupState extends State<MarcacaoPlantaPopup> {
  Offset? _ponto;
  String _tipoMarcacaoSelecionado = 'Retângulo'; 
  double _largura = 0.08;
  double _altura = 0.08;
  double _rotacao = 0.0;
  ModoFerramenta _modoAtivo = ModoFerramenta.navegar;

  @override
  void initState() {
    super.initState();
    if (widget.marcacaoInicial != null && widget.marcacaoInicial!.plantaId == widget.plantaId) {
      _ponto = Offset(widget.marcacaoInicial!.x, widget.marcacaoInicial!.y);
      
      // ✅ CORREÇÃO: Validação de segurança (Fallback)
      final tipoSalvo = widget.marcacaoInicial!.tipoMarcacao;
      if (tipoSalvo == 'Retângulo' || tipoSalvo == 'Círculo') {
        _tipoMarcacaoSelecionado = tipoSalvo;
      } else {
        // Se vier 'Linha', 'Ponto' ou qualquer lixo do banco, vira Retângulo por padrão
        _tipoMarcacaoSelecionado = 'Retângulo'; 
      }
      
      _largura = widget.marcacaoInicial!.largura;
      _altura = widget.marcacaoInicial!.altura;
      _rotacao = widget.marcacaoInicial!.rotacao;
      _modoAtivo = ModoFerramenta.mover; 
    }
  }

  void _salvar() {
    if (_ponto != null) {
      Navigator.of(context).pop(MarcacaoPlanta(
        x: _ponto!.dx, y: _ponto!.dy, plantaId: widget.plantaId, 
        tipoMarcacao: _tipoMarcacaoSelecionado, numero: widget.numero, 
        largura: _largura, altura: _altura, rotacao: _rotacao, 
      ));
    }
  }

  Widget _buildBotaoModo(ModoFerramenta modo, IconData icone, String texto) {
    final bool selecionado = _modoAtivo == modo;
    return InkWell(
      onTap: _ponto == null ? null : () => setState(() => _modoAtivo = modo),
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: _ponto == null ? 0.4 : 1.0,
        child: Container(
          width: 80, padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selecionado ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icone, size: 20, color: selecionado ? Colors.white : Colors.grey.shade700),
              const SizedBox(height: 4),
              Text(texto, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: selecionado ? Colors.white : Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPainelDinamico() {
    // Todos os painéis têm minHeight de 90px
    // Assim o mapa nunca é esmagado quando troca de ferramenta
    if (_ponto == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 90),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
        child: Row(
          children: [
            Icon(Icons.touch_app, size: 20, color: Colors.red.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text('Toque na planta para marcar o local inicial.', style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87))),
          ],
        ),
      );
    }

    if (_modoAtivo == ModoFerramenta.navegar || _modoAtivo == ModoFerramenta.mover) {
      return Container(
        constraints: const BoxConstraints(minHeight: 90),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
        child: Row(
          children: [
            Icon(_modoAtivo == ModoFerramenta.navegar ? Icons.zoom_out_map : Icons.open_with, size: 20, color: Colors.blue.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _modoAtivo == ModoFerramenta.navegar ? 'Arraste com 1 dedo para mover a planta, e 2 dedos para zoom.' : 'Arraste o dedo no ecrã vazio para deslizar a marcação.',
                style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    final bool isCirculo = _tipoMarcacaoSelecionado.toLowerCase() == 'círculo' || _tipoMarcacaoSelecionado.toLowerCase() == 'ponto';

    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajuste fino de tamanho:', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.swap_horiz, size: 18, color: Colors.orange.shade800),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                  child: Slider(
                    value: _largura, min: 0.01, max: 0.40, 
                    activeColor: Colors.orange.shade600, inactiveColor: Colors.orange.shade200,
                    onChanged: (val) {
                      setState(() { 
                        _largura = val; 
                        if (isCirculo) _altura = val; 
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          if (!isCirculo)
            Row(
              children: [
                Icon(Icons.swap_vert, size: 18, color: Colors.orange.shade800),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                    child: Slider(
                      value: _altura, min: 0.01, max: 0.40,
                      activeColor: Colors.orange.shade600, inactiveColor: Colors.orange.shade200,
                      onChanged: (val) => setState(() => _altura = val),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.rotate_right, size: 18, color: Colors.orange.shade800),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                    child: Slider(
                      value: _rotacao, min: 0, max: 360,
                      activeColor: Colors.orange.shade600, inactiveColor: Colors.orange.shade200,
                      onChanged: (val) => setState(() => _rotacao = val),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final larguraTela = (mediaQuery.size.width - 32).clamp(280.0, 380.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
        child: SizedBox(
          width: larguraTela,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerRight, child: _CloseButton(onPressed: () => Navigator.of(context).maybePop())),
                  Text('Marcação em Planta', textAlign: TextAlign.center, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _tipoMarcacaoSelecionado,
                      style: GoogleFonts.lato(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800),
                      items: ['Retângulo', 'Círculo'].map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))).toList(),
                      onChanged: (val) { 
                        if (val != null) {
                          setState(() { 
                            _tipoMarcacaoSelecionado = val; 
                            if (val.toLowerCase() == 'círculo') _altura = _largura;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBotaoModo(ModoFerramenta.navegar, Icons.pan_tool, 'Navegar'),
                      _buildBotaoModo(ModoFerramenta.mover, Icons.open_with, 'Mover'),
                      _buildBotaoModo(ModoFerramenta.redimensionar, Icons.aspect_ratio, 'Tamanho'),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _buildPainelDinamico(),
                  const SizedBox(height: 10),
                  
                  Flexible(
                    child: Container(
                      color: const Color(0xFFD9D9D9),
                      child: _PlantaInterativa(
                        arquivoUrl: widget.arquivoUrl, plantaId: widget.plantaId, estruturaId: widget.estruturaId, 
                        numero: widget.numero, ponto: _ponto, largura: _largura, altura: _altura,
                        tipoMarcacao: _tipoMarcacaoSelecionado, nomeElemento: widget.nomeElemento,   
                        modo: _modoAtivo,   
                        rotacao: _rotacao,
                        onInitialTap: (pontoInicial) {
                          setState(() {
                            _ponto = pontoInicial;
                            _modoAtivo = ModoFerramenta.redimensionar; 
                          });
                        },
                        onChanged: (novoPonto) {
                          setState(() => _ponto = novoPonto);
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 14),
                  Center(child: _SalvarButton(onPressed: _ponto != null ? _salvar : null)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlantaInterativa extends ConsumerStatefulWidget {
  const _PlantaInterativa({
    required this.arquivoUrl, required this.plantaId, this.estruturaId,
    required this.numero, required this.ponto, required this.largura, required this.altura,
    required this.tipoMarcacao, this.nomeElemento, required this.onChanged,
    required this.modo, required this.onInitialTap, required this.rotacao,
  });

  final String arquivoUrl, plantaId, tipoMarcacao;
  final String? estruturaId, nomeElemento;
  final int numero;
  final Offset? ponto;
  final double largura, altura, rotacao;
  final ModoFerramenta modo;
  final ValueChanged<Offset> onInitialTap;
  final ValueChanged<Offset> onChanged;


  @override
  ConsumerState<_PlantaInterativa> createState() => _PlantaInterativaState();
}

class _PlantaInterativaState extends ConsumerState<_PlantaInterativa> {
  bool _isPdf = false, _isLoadingPdf = false;
  Uint8List? _pdfImageBytes;

  @override
  void initState() {
    super.initState();
    _carregarPdf();
  }

  Future<void> _carregarPdf() async {
    if (!widget.arquivoUrl.toLowerCase().contains('.pdf')) return;
    setState(() { _isPdf = true; _isLoadingPdf = true; });
    try {
      final req = await HttpClient().getUrl(Uri.parse(widget.arquivoUrl));
      final res = await req.close();
      final bytes = await consolidateHttpClientResponseBytes(res);
      final doc = await PdfDocument.openData(bytes);
      final page = await doc.getPage(1);
      double w = page.width, h = page.height;
      if (w < 1000) { w *= 2; h *= 2; }
      final pageImg = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
      if (pageImg != null && mounted) setState(() => _pdfImageBytes = pageImg.bytes);
      await page.close(); await doc.close();
    } catch (_) {
      // Falha silenciosa
    } finally {
      if (mounted) setState(() => _isLoadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<ElementoModel> pinosVizinhos = [];
    if (widget.estruturaId != null) {
      final els = ref.watch(elementosPorEstruturaProvider(widget.estruturaId!)).value;
      pinosVizinhos = els?.where((el) => el.plantaId == widget.plantaId && el.posicaoX != null).toList() ?? [];
    }

    final bool permitirMoverPlanta = widget.ponto == null || widget.modo == ModoFerramenta.navegar;

    return InteractiveViewer(
      minScale: 1.0, maxScale: 5.0,
      panEnabled: permitirMoverPlanta, 
      scaleEnabled: permitirMoverPlanta,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // A IMAGEM DE FUNDO BASE
            if (_isPdf) ...[
              if (_isLoadingPdf) const Center(child: CircularProgressIndicator())
              else if (_pdfImageBytes != null) Image.memory(_pdfImageBytes!)
              else const Icon(Icons.broken_image, size: 50, color: Colors.grey)
            ] else Image.network(widget.arquivoUrl),

            // 🔥 A CAMADA DE INTERAÇÃO (Tira as coordenadas exatas da imagem)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double w = constraints.maxWidth;
                  final double h = constraints.maxHeight;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: widget.ponto != null ? null : (details) {
                      final local = details.localPosition;
                      widget.onInitialTap(Offset(
                        (local.dx / w).clamp(0.0, 1.0),
                        (local.dy / h).clamp(0.0, 1.0),
                      ));
                    },
                    // O Arraste agora usa a largura exata 'w' e 'h' da imagem
                    onPanUpdate: (widget.ponto != null && widget.modo == ModoFerramenta.mover)
                        ? (details) {
                            final novoX = (widget.ponto!.dx + (details.delta.dx / w)).clamp(0.0, 1.0);
                            final novoY = (widget.ponto!.dy + (details.delta.dy / h)).clamp(0.0, 1.0);
                            widget.onChanged(Offset(novoX, novoY));
                          }
                        : null,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ...pinosVizinhos.map((el) {
                          final cx = el.posicaoX! * w;
                          final cy = el.posicaoY! * h;
                          final wPino = (el.marcacaoLargura ?? 0.12) * w;
                          final hPino = (el.marcacaoAltura ?? 0.08) * h;
                          return Positioned(
                            left: cx - (wPino / 2), top: cy - (hPino / 2),
                            child: Opacity(
                              opacity: 0.35, 
                              child: PinoDinamico(
                                tipoMarcacao: el.tipoMarcacao ?? 'Retângulo', 
                                largura: wPino, 
                                altura: hPino,
                                rotacao: el.marcacaoRotacao ?? 0.0, // 🔥 AQUI: Gira os vizinhos também
                              )
                            ),
                          );
                        }),

                        if (widget.ponto != null) ...[
                          () {
                            final wPixels = widget.largura * w;
                            final hPixels = widget.altura * h;
                            final cxPixels = widget.ponto!.dx * w;
                            final cyPixels = widget.ponto!.dy * h;

                            return Positioned(
                              left: cxPixels - (wPixels / 2),
                              top: cyPixels - (hPixels / 2),
                              // O pino agora é apenas visual, o usuário não clica nele
                              child: IgnorePointer(
                                child: PinoDinamico(
                                  tipoMarcacao: widget.tipoMarcacao, 
                                  largura: wPixels, 
                                  altura: hPixels,
                                  numero: widget.numero, 
                                  nomeElemento: widget.nomeElemento,
                                  ocultarTexto: widget.modo == ModoFerramenta.redimensionar, 
                                  rotacao: widget.rotacao, // 🔥 AQUI: Faz o pino girar ao vivo!
                                ),
                              ),
                            );
                          }()
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalvarButton extends StatelessWidget {
  const _SalvarButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      child: Text('Confirmar Área', style: GoogleFonts.lato(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: onPressed, padding: EdgeInsets.zero, icon: const Icon(Icons.close, color: Colors.grey, size: 24));
  }
}