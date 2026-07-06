import 'dart:io';
import 'dart:math' as math;
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/constants/app_text_styles.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';

// ----------------------------------------------------------------------
// CLASSES DE DADOS E ENUMS
// ----------------------------------------------------------------------

class MarcacaoPlanta {
  const MarcacaoPlanta({
    required this.x,
    required this.y,
    required this.plantaId,
    this.tipoMarcacao = 'Retângulo',
    this.numero = 1,
    this.thumbnailBytes,
    this.nomeElemento,
    this.largura = 0.08,
    this.altura = 0.06,
    this.rotacao = 0.0,
    this.cor = '#FF9800',
    this.nomeX = 0.0,
    this.nomeY = 0.0,
  });

  final double x, y, largura, altura, rotacao, nomeX, nomeY;
  final String plantaId, tipoMarcacao, cor;
  final int numero;
  final Uint8List? thumbnailBytes;
  final String? nomeElemento;

  MarcacaoPlanta copyWith({
    double? x, double? y, String? plantaId, String? tipoMarcacao, 
    int? numero, Uint8List? thumbnailBytes, double? largura, double? altura, 
    double? rotacao, String? cor, double? nomeX, double? nomeY,
  }) {
    return MarcacaoPlanta(
      x: x ?? this.x, y: y ?? this.y, plantaId: plantaId ?? this.plantaId,
      tipoMarcacao: tipoMarcacao ?? this.tipoMarcacao, numero: numero ?? this.numero,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      largura: largura ?? this.largura, altura: altura ?? this.altura,
      rotacao: rotacao ?? this.rotacao, cor: cor ?? this.cor,
      nomeX: nomeX ?? this.nomeX, nomeY: nomeY ?? this.nomeY,
    );
  }

  Map<String, dynamic> toPosicaoMap() => <String, dynamic>{
        'posicao_x': x, 'posicao_y': y, 'planta_id': plantaId,
        'tipo_marcacao': tipoMarcacao, 'marcacao_largura': largura, 'marcacao_altura': altura,
        'marcacao_rotacao': rotacao, 'marcacao_cor': cor,
        'marcacao_nome_x': nomeX, 'marcacao_nome_y': nomeY,
      };
}

enum ModoFerramenta { navegar, mover, redimensionar }

Future<MarcacaoPlanta?> showMarcacaoPlantaPopup(
  BuildContext context, {
  required String arquivoUrl,
  required String plantaId,
  String? estruturaId,
  MarcacaoPlanta? inicial,
  int numero = 1,
  String? nomeElemento,
}) {
  return showDialog<MarcacaoPlanta>(
    context: context,
    barrierDismissible: false,
    useSafeArea: false,
    builder: (context) => MarcacaoPlantaPopup(
      arquivoUrl: arquivoUrl,
      plantaId: plantaId,
      estruturaId: estruturaId,
      marcacaoInicial: inicial,
      numero: numero,
      nomeElemento: nomeElemento,
    ),
  );
}

// ----------------------------------------------------------------------
// WIDGET PRINCIPAL DO POPUP
// ----------------------------------------------------------------------

class MarcacaoPlantaPopup extends StatefulWidget {
  const MarcacaoPlantaPopup({
    super.key,
    required this.arquivoUrl,
    required this.plantaId,
    this.estruturaId,
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
  final TransformationController _transformationController = TransformationController();

  Offset? _ponto;
  String _tipoMarcacaoSelecionado = 'Retângulo';
  double _largura = 0.08;
  double _altura = 0.08;
  double _rotacao = 0.0;
  ModoFerramenta _modoAtivo = ModoFerramenta.navegar;
  
  String _corSelecionada = '#FF9800'; 
  double _nomeX = 0.0;
  double _nomeY = 0.0;

  // 🔥 NOVO: Lista estática! Ela não zera quando fecha o popup, lembrando as escolhas do usuário
  static final List<String> _coresSalvas = ['#FF9800', '#F44336', '#2196F3']; 

  @override
  void initState() {
    super.initState();
    if (widget.marcacaoInicial != null) {
      _ponto = Offset(widget.marcacaoInicial!.x, widget.marcacaoInicial!.y);
      final tipoSalvo = widget.marcacaoInicial!.tipoMarcacao;
      if (tipoSalvo.isNotEmpty && ['Retângulo', 'Círculo', 'Linha', 'Ponto'].contains(tipoSalvo)) {
        _tipoMarcacaoSelecionado = tipoSalvo;
      }
      _largura = widget.marcacaoInicial!.largura;
      _altura = widget.marcacaoInicial!.altura;
      _rotacao = widget.marcacaoInicial!.rotacao;
      _corSelecionada = widget.marcacaoInicial!.cor;
      _nomeX = widget.marcacaoInicial!.nomeX;
      _nomeY = widget.marcacaoInicial!.nomeY;
      
      if (_nomeY < -1.0 || _nomeY > 2.0) {
        _nomeX = _ponto!.dx;
        _nomeY = _ponto!.dy - 0.06;
      }

      // 🔥 NOVO: Se o elemento já tiver uma cor que não está na lista, adiciona ela!
      if (!_coresSalvas.contains(_corSelecionada)) {
        _coresSalvas.add(_corSelecionada);
      }

      _modoAtivo = ModoFerramenta.mover;
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xff')));
  }

  void _salvar() {
    if (_ponto != null) {
      Navigator.of(context).pop(MarcacaoPlanta(
        x: _ponto!.dx,
        y: _ponto!.dy,
        plantaId: widget.plantaId,
        tipoMarcacao: _tipoMarcacaoSelecionado,
        numero: widget.numero,
        largura: _largura,
        altura: _altura,
        rotacao: _rotacao,
        cor: _corSelecionada,
        nomeX: _nomeX,
        nomeY: _nomeY,
        nomeElemento: widget.nomeElemento,
      ));
    }
  }

  void _abrirColorPicker() {
    Color corTemporaria = _hexToColor(_corSelecionada);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escolha a cor', style: AppTextStyles.tituloPrincipal),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: corTemporaria,
            onColorChanged: (Color color) => corTemporaria = color,
            enableAlpha: false,
            labelTypes: const [], 
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.greyMedium)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                _corSelecionada = '#${corTemporaria.value.toRadixString(16).substring(2).toUpperCase()}';
                
                // 🔥 NOVO: Adiciona a cor escolhida à lista se ela ainda não existir
                if (!_coresSalvas.contains(_corSelecionada)) {
                  _coresSalvas.add(_corSelecionada);
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text('Salvar', style: AppTextStyles.corpoDestaqueBranco),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletaCores() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cor da Marcação', style: AppTextStyles.labelCampo), 
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 🔥 NOVO: Agora usa a nossa lista estática em vez de uma lista fixa
                ..._coresSalvas.map((cor) {
                  final isSelected = _corSelecionada == cor;
                  return GestureDetector(
                    onTap: () => setState(() => _corSelecionada = cor),
                    child: Container(
                      margin: const EdgeInsets.only(right: 14),
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _hexToColor(cor),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: AppColors.greyDarkest, width: 2.5) : Border.all(color: Colors.black12),
                        boxShadow: [if (isSelected) const BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _abrirColorPicker,
                  child: Container(
                    margin: const EdgeInsets.only(right: 14),
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.inputBorder, width: 1.5),
                    ),
                    child: const Icon(Icons.colorize, size: 18, color: AppColors.greyMedium),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoModo(ModoFerramenta modo, IconData icon, String label) {
    final isActive = _modoAtivo == modo;
    return GestureDetector(
      onTap: () => setState(() => _modoAtivo = modo),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary.withValues(alpha: 0.1) : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: isActive ? AppColors.primary : AppColors.greyVeryLight, width: 2),
              boxShadow: isActive ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Icon(icon, color: isActive ? AppColors.primary : AppColors.greyMedium, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label, 
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.greyMedium, 
              fontSize: 13, 
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'Lato', 
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCirculo = _tipoMarcacaoSelecionado.toLowerCase() == 'círculo';

    return Scaffold(
      backgroundColor: AppColors.background, 
      appBar: const CustomAppBar( 
        title: 'Marcar na Planta',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // PLANTA INTERATIVA
            Flexible(
              child: Container(
                color: AppColors.greyVeryLight,
                child: _PlantaInterativa(
                  transformationController: _transformationController,
                  arquivoUrl: widget.arquivoUrl, 
                  plantaId: widget.plantaId, 
                  estruturaId: widget.estruturaId, 
                  numero: widget.numero, 
                  ponto: _ponto, 
                  largura: _largura, 
                  altura: _altura,
                  tipoMarcacao: _tipoMarcacaoSelecionado, 
                  nomeElemento: widget.nomeElemento,   
                  modo: _modoAtivo,   
                  rotacao: _rotacao,
                  corSelecionada: _corSelecionada, 
                  nomeX: _nomeX,                   
                  nomeY: _nomeY,                   
                  onNomeDrag: (deltaFraction) {       
                    setState(() {
                      _nomeX = (_nomeX + deltaFraction.dx).clamp(0.0, 1.0);
                      _nomeY = (_nomeY + deltaFraction.dy).clamp(0.0, 1.0);
                    });
                  }, 
                  onInitialTap: (pontoInicial) {
                    setState(() {
                      _ponto = pontoInicial;
                      _nomeX = pontoInicial.dx;
                      _nomeY = (pontoInicial.dy - 0.06).clamp(0.0, 1.0); 
                      _modoAtivo = ModoFerramenta.redimensionar; 
                    });
                  },
                  onChanged: (novoPonto) {
                    setState(() => _ponto = novoPonto);
                  },
                ),
              ),
            ),

            // PAINEL DE CONTROLE INFERIOR
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: AppColors.white, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBotaoModo(ModoFerramenta.navegar, Icons.pan_tool, 'Navegar'),
                      _buildBotaoModo(ModoFerramenta.mover, Icons.open_with, 'Mover'),
                      _buildBotaoModo(ModoFerramenta.redimensionar, Icons.aspect_ratio, 'Tamanho'),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: AppColors.greyVeryLight),
                  ),
                  
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.30),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_modoAtivo != ModoFerramenta.redimensionar) ...[
                            const Text('Tipo de Marcação', style: AppTextStyles.labelCampo), 
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: DropdownButtonFormField<String>(
                                value: _tipoMarcacaoSelecionado,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                                ),
                                style: AppTextStyles.corpoTextoEscuro,
                                items: ['Retângulo', 'Círculo', 'Linha', 'Ponto']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (val) => setState(() => _tipoMarcacaoSelecionado = val!),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildPaletaCores(),
                          ],

                          if (_modoAtivo == ModoFerramenta.redimensionar) ...[
                            const Text('Ajuste de Dimensões e Rotação', style: AppTextStyles.labelCampo), 
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.straighten, size: 20, color: AppColors.primary),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                                    child: Slider(
                                      value: _largura, min: 0.01, max: 0.40,
                                      activeColor: AppColors.primary, inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                                      onChanged: (val) => setState(() => _largura = val),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isCirculo) ...[
                              Row(
                                children: [
                                  const Icon(Icons.swap_vert, size: 20, color: AppColors.primary),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                                      child: Slider(
                                        value: _altura, min: 0.01, max: 0.40,
                                        activeColor: AppColors.primary, inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                                        onChanged: (val) => setState(() => _altura = val),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.rotate_right, size: 20, color: AppColors.primary),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                                      child: Slider(
                                        value: _rotacao, min: 0, max: 360,
                                        activeColor: AppColors.primary, inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                                        onChanged: (val) => setState(() => _rotacao = val),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: CompactButton(
                          text: 'Cancelar',
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.greyMedium,
                          borderColor: AppColors.greyMedium,
                          elevation: 0,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CompactButton(
                          text: 'Salvar',
                          backgroundColor: _ponto == null ? AppColors.greyLight : AppColors.primary,
                          foregroundColor: AppColors.white,
                          onPressed: () {
                            if (_ponto != null) _salvar();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET DO PINO DINÂMICO
// ----------------------------------------------------------------------

class PinoDinamico extends StatelessWidget {
  const PinoDinamico({
    super.key, 
    required this.tipoMarcacao, 
    this.numero = 1, 
    this.largura, 
    this.altura, 
    this.ocultarTexto = false, 
    this.rotacao = 0.0,
    this.corBase = Colors.orange,
    this.mostrarNumero = false, // 🔥 NOVO: Agora inicia oculto por padrão!
  });

  final String tipoMarcacao;
  final int numero;
  final double? largura, altura;
  final bool ocultarTexto;
  final double rotacao;
  final Color corBase;
  final bool mostrarNumero; // 🔥 NOVO

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
      clipBehavior: Clip.none, 
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: rotacao * (math.pi / 180),
          child: Container(
            width: larguraPino, 
            height: alturaPino, 
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: corBase.withValues(alpha: 0.45), 
              shape: isCirculo ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: (!isCirculo && !isLinha) ? BorderRadius.circular(2) : null,
              border: Border.all(color: corBase, width: 1.0), 
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            // 🔥 SÓ EXIBE SE mostrarNumero FOR PASSADO COMO TRUE
            child: (mostrarNumero && !ocultarTexto && tipo != 'ponto' && !isLinha) 
                ? Transform.rotate(
                    angle: -rotacao * (math.pi / 180), 
                    child: Text(
                      '$numero', 
                      style: GoogleFonts.lato(color: corBase, fontSize: larguraPino > 24 ? 13 : 9, fontWeight: FontWeight.w900)
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET DO VISUALIZADOR DA PLANTA
// ----------------------------------------------------------------------

class _PlantaInterativa extends ConsumerStatefulWidget {
  const _PlantaInterativa({
    required this.transformationController,
    required this.arquivoUrl, required this.plantaId, this.estruturaId,
    required this.numero, required this.ponto, required this.largura, required this.altura,
    required this.tipoMarcacao, this.nomeElemento, required this.onChanged,
    required this.modo, required this.onInitialTap, required this.rotacao,
    required this.corSelecionada, required this.nomeX, required this.nomeY,
    required this.onNomeDrag,
  });

  final TransformationController transformationController;
  final String arquivoUrl, plantaId, tipoMarcacao;
  final String? estruturaId, nomeElemento;
  final int numero;
  final Offset? ponto;
  final double largura, altura, rotacao, nomeX, nomeY;
  final String corSelecionada;
  final ValueChanged<Offset> onChanged, onInitialTap, onNomeDrag;
  final ModoFerramenta modo;

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
      transformationController: widget.transformationController,
      minScale: 1.0, maxScale: 5.0,
      panEnabled: permitirMoverPlanta, 
      scaleEnabled: permitirMoverPlanta,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (_isPdf) ...[
              if (_isLoadingPdf) const Center(child: CircularProgressIndicator(color: AppColors.primary))
              else if (_pdfImageBytes != null) Image.memory(_pdfImageBytes!)
              else const Icon(Icons.broken_image, size: 50, color: AppColors.greyMedium)
            ] else Image.network(widget.arquivoUrl),

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
                        ...pinosVizinhos.expand((el) {
                          final cx = el.posicaoX! * w;
                          final cy = el.posicaoY! * h;
                          final wPino = (el.marcacaoLargura ?? 0.12) * w;
                          final hPino = (el.marcacaoAltura ?? 0.08) * h;
                          final corVizinho = el.marcacaoCor != null 
                              ? Color(int.parse(el.marcacaoCor!.replaceFirst('#', '0xff'))) 
                              : AppColors.primary;

                          final pino = Positioned(
                            left: cx - (wPino / 2), top: cy - (hPino / 2),
                            child: Opacity(
                              opacity: 0.35, 
                              child: PinoDinamico(
                                tipoMarcacao: el.tipoMarcacao ?? 'Retângulo', 
                                largura: wPino, altura: hPino,
                                rotacao: el.marcacaoRotacao ?? 0.0,
                                corBase: corVizinho,
                                mostrarNumero: false, // Oculto aqui
                              )
                            ),
                          );

                          Widget? nomeVizinho;
                          if (el.nome != null && el.nome!.isNotEmpty) {
                             double nx = el.marcacaoNomeX ?? el.posicaoX!;
                             double ny = el.marcacaoNomeY ?? el.posicaoY!;
                             if (ny < -1.0 || ny > 2.0) { nx = el.posicaoX!; ny = el.posicaoY! - 0.06; }
                             
                             nomeVizinho = Positioned(
                               left: nx * w, top: ny * h,
                               child: FractionalTranslation(
                                 translation: const Offset(-0.5, -0.5),
                                 child: Text(
                                   el.nome!, 
                                   style: TextStyle(
                                     color: corVizinho.withValues(alpha: 0.5), 
                                     fontSize: 12, fontWeight: FontWeight.bold,
                                     shadows: const [Shadow(color: Colors.white, blurRadius: 4)]
                                   )
                                 ),
                               ),
                             );
                          }
                          return [pino, if (nomeVizinho != null) nomeVizinho];
                        }),

                        if (widget.ponto != null) ...[
                          () {
                            final wPixels = widget.largura * w;
                            final hPixels = widget.altura * h;
                            final cxPixels = widget.ponto!.dx * w;
                            final cyPixels = widget.ponto!.dy * h;

                            return Positioned(
                              left: cxPixels - (wPixels / 2), top: cyPixels - (hPixels / 2),
                              child: PinoDinamico(
                                tipoMarcacao: widget.tipoMarcacao, 
                                largura: wPixels, altura: hPixels,
                                numero: widget.numero, 
                                ocultarTexto: widget.modo == ModoFerramenta.redimensionar, 
                                rotacao: widget.rotacao,
                                corBase: Color(int.parse(widget.corSelecionada.replaceFirst('#', '0xff'))),
                                mostrarNumero: false, // Oculto aqui também
                              ),
                            );
                          }(),
                          
                          if (widget.nomeElemento != null)
                            Positioned(
                              left: widget.nomeX * w, top: widget.nomeY * h,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanUpdate: (details) {
                                    widget.onNomeDrag(Offset(details.delta.dx / w, details.delta.dy / h));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0), 
                                    child: Text(
                                      widget.nomeElemento!,
                                      style: TextStyle(
                                        color: Color(int.parse(widget.corSelecionada.replaceFirst('#', '0xff'))),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [Shadow(color: Colors.white, blurRadius: 4)] 
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ]
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