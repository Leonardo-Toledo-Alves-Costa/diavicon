import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_dropdown.dart';
import '../../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../elementos/screens/novo_elem_estrutural_screen.dart';
import '../../../empresa/providers/sistema_provider.dart';
import '../../ensaios_prova_carga/providers/prova_carga_providers.dart';
import '../models/extracao_model.dart';
import '../utils/extracao_math.dart';
import '../../../../core/web/escolher_foto.dart';

/// Formulário de um novo (ou edição de um) ponto de extração — Sistema >
/// Tipo > Elemento (filtrados pelo Local já fixo do ensaio), nome do ponto,
/// marcação na planta (toque pra posicionar), fotos, fatores k1-k4 e
/// resistência corrigida (calculada automaticamente pela ABNT NBR
/// 7680-1:2015, ver `ExtracaoMath`). Devolve um Map via Navigator.pop.
class NovoPontoExtracaoModal extends ConsumerStatefulWidget {
  final String estruturaId;
  final String localNome;
  final String plantaUrl;
  final List<LeituraExtracaoModel> pontosExistentes;
  final LeituraExtracaoModel? leituraExistente;
  final int numeroVisual;

  const NovoPontoExtracaoModal({
    super.key,
    required this.estruturaId,
    required this.localNome,
    required this.plantaUrl,
    required this.pontosExistentes,
    this.leituraExistente,
    required this.numeroVisual,
  });

  @override
  ConsumerState<NovoPontoExtracaoModal> createState() => _NovoPontoExtracaoModalState();
}

class _NovoPontoExtracaoModalState extends ConsumerState<NovoPontoExtracaoModal> {
  final _nomeCtrl = TextEditingController();
  final _relacaoHDCtrl = TextEditingController();
  final _diametroCtrl = TextEditingController();
  final _resistSemCorrecaoCtrl = TextEditingController();
  final GlobalKey _marcacaoRepaintKey = GlobalKey();

  String? _sistemaId;
  String? _tipoElementoNome;
  String? _elementoId;
  Offset? _posicao;

  DirecaoExtracao _direcao = DirecaoExtracao.paralelo;
  CondicaoUmidade _umidade = CondicaoUmidade.secoAoAr;

  File? _fotoExtraindoLocal, _fotoExtracaoLocal, _fotoRecomposicaoLocal;
  String? _fotoExtraindoUrl, _fotoExtracaoUrl, _fotoRecomposicaoUrl;

  bool _isPdf = false;
  bool _carregandoPlanta = false;
  bool _salvando = false;
  Uint8List? _plantaBytes;

  @override
  void initState() {
    super.initState();
    final l = widget.leituraExistente;
    _nomeCtrl.text = l?.nomeTestemunho ?? 'P${widget.numeroVisual}';
    _relacaoHDCtrl.text = (l?.relacaoHD ?? 2.0).toString();
    _diametroCtrl.text = (l?.diametroTestemunho ?? 100).toString();
    _resistSemCorrecaoCtrl.text = l?.resistenciaSemCorrecao.toString() ?? '';
    _tipoElementoNome = l != null && l.tipoElemento.isNotEmpty ? l.tipoElemento : null;
    _elementoId = l?.elementoId;
    _posicao = l != null ? Offset(l.posX, l.posY) : null;
    _direcao = l?.direcao ?? DirecaoExtracao.paralelo;
    _umidade = l?.condicaoUmidade ?? CondicaoUmidade.secoAoAr;
    _fotoExtraindoUrl = l?.fotoExtraindo;
    _fotoExtracaoUrl = l?.fotoExtracao;
    _fotoRecomposicaoUrl = l?.fotoRecomposicao;
    _relacaoHDCtrl.addListener(() => setState(() {}));
    _diametroCtrl.addListener(() => setState(() {}));
    _resistSemCorrecaoCtrl.addListener(() => setState(() {}));
    _carregarPlanta();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _relacaoHDCtrl.dispose();
    _diametroCtrl.dispose();
    _resistSemCorrecaoCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPlanta() async {
    if (!widget.plantaUrl.toLowerCase().contains('.pdf')) return;
    setState(() {
      _isPdf = true;
      _carregandoPlanta = true;
    });
    try {
      final req = await HttpClient().getUrl(Uri.parse(await StorageUrls.assinar(widget.plantaUrl)));
      final doc = await PdfDocument.openData(await consolidateHttpClientResponseBytes(await req.close()));
      final page = await doc.getPage(1);
      double w = page.width, h = page.height;
      if (w < 1000) {
        w *= 2.0;
        h *= 2.0;
      }
      final pageImg = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
      if (pageImg != null && mounted) setState(() => _plantaBytes = pageImg.bytes);
      await page.close();
      await doc.close();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _carregandoPlanta = false);
    }
  }

  Future<void> _escolherFoto(void Function(File) onEscolhida) async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (source == null) return;
    final imagem = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (imagem != null) setState(() => onEscolhida(File(imagem.path)));
  }

  Future<void> _adicionarElemento() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NovoElemEstruturalScreen(estruturaId: widget.estruturaId, initialLocalElemento: widget.localNome)));
    ref.invalidate(elementosPorLocalProvaCargaProvider);
  }

  double? get _resistenciaCorrigidaPreview {
    final semCorrecao = double.tryParse(_resistSemCorrecaoCtrl.text.replaceAll(',', '.'));
    final hd = double.tryParse(_relacaoHDCtrl.text.replaceAll(',', '.'));
    final diametro = double.tryParse(_diametroCtrl.text.replaceAll(',', '.'));
    if (semCorrecao == null || hd == null || diametro == null) return null;
    return ExtracaoMath.resistenciaCorrigida(resistenciaSemCorrecao: semCorrecao, relacaoHD: hd, diametroTestemunho: diametro, direcao: _direcao, umidade: _umidade);
  }

  Future<File?> _capturarMarcacaoPonto() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _marcacaoRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final file = File('${Directory.systemTemp.path}/extracao_ponto_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      return file;
    } catch (e) {
      debugPrint('Erro ao capturar marcação do ponto: $e');
      return null;
    }
  }

  Future<void> _salvar() async {
    if (_tipoElementoNome == null || _elementoId == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Selecione o tipo e o elemento.', isErro: true);
      return;
    }
    if (_nomeCtrl.text.trim().isEmpty) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome do ponto.', isErro: true);
      return;
    }
    if (_posicao == null) {
      DiaviconAlerts.show(context, 'Marque a posição', 'Toque na planta pra marcar a posição do ponto.', isErro: true);
      return;
    }
    final resistSemCorrecao = double.tryParse(_resistSemCorrecaoCtrl.text.replaceAll(',', '.'));
    if (resistSemCorrecao == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe a resistência sem correção.', isErro: true);
      return;
    }
    final diametro = double.tryParse(_diametroCtrl.text.replaceAll(',', '.'));
    if (diametro == null) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o diâmetro do testemunho.', isErro: true);
      return;
    }
    if (ExtracaoMath.k2DeDiametro(diametro) == null) {
      DiaviconAlerts.show(context, 'Diâmetro não permitido', 'A ABNT NBR 7680-1 não permite testemunhos com diâmetro menor que 50 mm.', isErro: true);
      return;
    }
    final relacaoHD = double.tryParse(_relacaoHDCtrl.text.replaceAll(',', '.')) ?? 2.0;

    setState(() => _salvando = true);
    final fotoPlanta = await _capturarMarcacaoPonto();
    if (!mounted) return;

    Navigator.pop(context, {
      'elementoId': _elementoId,
      'tipoElemento': _tipoElementoNome,
      'nomeTestemunho': _nomeCtrl.text.trim(),
      'posX': _posicao!.dx,
      'posY': _posicao!.dy,
      'fotoExtraindo': _fotoExtraindoLocal,
      'fotoExtracao': _fotoExtracaoLocal,
      'fotoRecomposicao': _fotoRecomposicaoLocal,
      'fotoPlanta': fotoPlanta,
      'direcao': _direcao,
      'relacaoHD': relacaoHD,
      'diametroTestemunho': diametro,
      'condicaoUmidade': _umidade,
      'resistenciaSemCorrecao': resistSemCorrecao,
    });
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600, letterSpacing: 0.3)),
      );

  Widget _campoFoto(String titulo, File? local, String? url, VoidCallback onTap) {
    ImageProvider? img;
    if (local != null) {
      img = FileImage(local);
    } else if (url != null && url.isNotEmpty) {
      img = StorageNetworkImage(url);
    }
    return Column(
      children: [
        Text(titulo, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        // Proporção fixa em vez de altura fixa: a foto não achata em tela
        // larga. Tocar continua trocando a foto.
        FotoEnsaio(
          imagem: img,
          raio: 10,
          aoTocar: onTap,
          vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 22)),
        ),
      ],
    );
  }

  Widget _botaoOpcao<T>(T valor, T selecionado, String label, void Function(T) onTap) {
    final sel = valor == selecionado;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(valor),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent, border: Border.all(color: sel ? AppColors.primary : const Color(0xFF9E9E9E)), borderRadius: BorderRadius.circular(10)),
          child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : Colors.grey.shade700)),
        ),
      ),
    );
  }

  Widget _buildMarcacaoPlanta() {
    final ImageProvider? imagem = _isPdf ? (_plantaBytes != null ? MemoryImage(_plantaBytes!) : null) : StorageNetworkImage(widget.plantaUrl);

    return RepaintBoundary(
      key: _marcacaoRepaintKey,
      child: Container(
        height: 220,
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.hardEdge,
        child: _carregandoPlanta
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : imagem == null
                ? const Center(child: Text('Planta não disponível', style: TextStyle(color: Colors.grey)))
                // Planta inteira, na proporção real: posX/posY são frações da
                // imagem completa, como o croqui desenha. Antes a imagem era
                // cortada (BoxFit.cover) e a marcação saía deslocada no croqui.
                : _PlantaProporcionalDesktop(imagem: imagem, builder: (w, h) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(image: imagem, fit: BoxFit.fill),
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (details) => setState(() => _posicao = Offset((details.localPosition.dx / w).clamp(0.0, 1.0), (details.localPosition.dy / h).clamp(0.0, 1.0))),
                          ),
                        ),
                        ...widget.pontosExistentes.where((p) => p.id != widget.leituraExistente?.id).map((p) {
                          return Positioned(
                            left: (p.posX * w) - 12,
                            top: (p.posY * h) - 12,
                            child: IgnorePointer(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                              ),
                            ),
                          );
                        }),
                        if (_posicao != null)
                          Positioned(
                            left: (_posicao!.dx * w) - 14,
                            top: (_posicao!.dy * h) - 14,
                            child: IgnorePointer(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                                child: Center(child: Text('${widget.numeroVisual}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ehEdicao = widget.leituraExistente != null;
    final empresaId = ref.watch(currentUserProvider)?.empresaId;
    final resistenciaCorrigida = _resistenciaCorrigidaPreview;
    final diametroInformado = double.tryParse(_diametroCtrl.text.replaceAll(',', '.'));
    final diametroInvalido = diametroInformado != null && ExtracaoMath.k2DeDiametro(diametroInformado) == null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ehEdicao ? 'Editar ponto de extração' : 'Novo ponto de extração', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
                child: Text('Local: ${widget.localNome}', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 12),
              if (empresaId == null)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else ...[
                Consumer(builder: (context, ref, _) {
                  final sistemasAsync = ref.watch(sistemasDropdownProvider(empresaId));
                  return sistemasAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Text('Erro: $err', style: const TextStyle(color: Colors.red, fontSize: 11)),
                    data: (sistemas) => CustomDropdown<String>(
                      label: 'Sistema',
                      value: _sistemaId,
                      items: sistemas.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nome, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() {
                        _sistemaId = val;
                        _tipoElementoNome = null;
                        _elementoId = null;
                      }),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Consumer(builder: (context, ref, _) {
                  final tiposAsync = ref.watch(tiposElementoDropdownProvider(empresaId));
                  return tiposAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Text('Erro: $err', style: const TextStyle(color: Colors.red, fontSize: 11)),
                    data: (tipos) {
                      final tiposFiltrados = _sistemaId == null ? tipos : tipos.where((t) => t.sistemaId == _sistemaId).toList();
                      return CustomDropdown<String>(
                        label: 'Tipo',
                        value: _tipoElementoNome,
                        items: tiposFiltrados.map((t) => DropdownMenuItem(value: t.nome, child: Text(t.nome, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() {
                          _tipoElementoNome = val;
                          _elementoId = null;
                        }),
                      );
                    },
                  );
                }),
                const SizedBox(height: 12),
                Consumer(builder: (context, ref, _) {
                  final elementosAsync = ref.watch(elementosPorLocalProvaCargaProvider((estruturaId: widget.estruturaId, local: widget.localNome, tipoNome: _tipoElementoNome)));
                  return elementosAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    error: (err, _) => Text('Erro: $err', style: const TextStyle(color: Colors.red, fontSize: 11)),
                    data: (elementos) {
                      if (_elementoId != null && !elementos.any((e) => e['id'] == _elementoId)) _elementoId = null;
                      return CustomDropdownWithAdd<String>(
                        label: 'Elemento',
                        hint: _tipoElementoNome == null ? 'Selecione o tipo' : (elementos.isEmpty ? 'Nenhum elemento' : 'Selecione'),
                        value: _elementoId,
                        items: elementos.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['nome'] ?? 'Sem nome', overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: _tipoElementoNome == null ? null : (val) => setState(() => _elementoId = val),
                        onAddPressed: _adicionarElemento,
                        isRequired: true,
                      );
                    },
                  );
                }),
              ],
              const SizedBox(height: 12),
              CustomTextField(label: 'Nome do ponto', hint: 'Ex: P1', controller: _nomeCtrl, isRequired: true),
              _rotulo('TOQUE NA PLANTA PRA MARCAR A POSIÇÃO'),
              _buildMarcacaoPlanta(),
              _rotulo('FOTOS'),
              Row(
                children: [
                  Expanded(child: _campoFoto('Extraindo', _fotoExtraindoLocal, _fotoExtraindoUrl, () => _escolherFoto((f) => _fotoExtraindoLocal = f))),
                  const SizedBox(width: 8),
                  Expanded(child: _campoFoto('Extração', _fotoExtracaoLocal, _fotoExtracaoUrl, () => _escolherFoto((f) => _fotoExtracaoLocal = f))),
                  const SizedBox(width: 8),
                  Expanded(child: _campoFoto('Recomposição', _fotoRecomposicaoLocal, _fotoRecomposicaoUrl, () => _escolherFoto((f) => _fotoRecomposicaoLocal = f))),
                ],
              ),
              _rotulo('DIREÇÃO DA EXTRAÇÃO · K3'),
              Row(children: DirecaoExtracao.values.map((d) => _botaoOpcao(d, _direcao, d.label, (v) => setState(() => _direcao = v))).toList()),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_rotulo('RELAÇÃO H/D · K1'), TextField(controller: _relacaoHDCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rotulo('DIÂMETRO DO TESTEMUNHO (mm) · K2'),
                        TextField(
                          controller: _diametroCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            errorText: diametroInvalido ? 'Mínimo 50 mm' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _rotulo('CONDIÇÃO DE UMIDADE · K4'),
              Row(children: CondicaoUmidade.values.map((c) => _botaoOpcao(c, _umidade, c.label, (v) => setState(() => _umidade = v))).toList()),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_rotulo('RESIST. SEM CORREÇÃO (MPa)'), TextField(controller: _resistSemCorrecaoCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))))],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _rotulo('RESIST. CORRIGIDA (CALC.)'),
                        Container(
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD9D9D9))),
                          child: Text(
                            resistenciaCorrigida != null ? '${resistenciaCorrigida.toStringAsFixed(1)} MPa' : '—',
                            style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: _salvando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Salvar ponto', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Planta na proporção real da imagem, o maior possível no espaço dado.
/// Chama [builder] com a largura/altura efetivas da imagem na tela.
class _PlantaProporcionalDesktop extends StatefulWidget {
  final ImageProvider imagem;
  final Widget Function(double w, double h) builder;
  const _PlantaProporcionalDesktop({required this.imagem, required this.builder});

  @override
  State<_PlantaProporcionalDesktop> createState() => _PlantaProporcionalDesktopState();
}

class _PlantaProporcionalDesktopState extends State<_PlantaProporcionalDesktop> {
  double? _proporcao;
  ImageStream? _stream;
  ImageStreamListener? _ouvinte;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolver();
  }

  @override
  void didUpdateWidget(covariant _PlantaProporcionalDesktop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagem != widget.imagem) _resolver();
  }

  void _resolver() {
    if (_ouvinte != null) _stream?.removeListener(_ouvinte!);
    _stream = widget.imagem.resolve(createLocalImageConfiguration(context));
    _ouvinte = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && h > 0 && _proporcao != w / h) setState(() => _proporcao = w / h);
    });
    _stream!.addListener(_ouvinte!);
  }

  @override
  void dispose() {
    if (_ouvinte != null) _stream?.removeListener(_ouvinte!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proporcao = _proporcao;
    if (proporcao == null) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return Center(
      child: AspectRatio(
        aspectRatio: proporcao,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(builder: (context, c) => widget.builder(c.maxWidth, c.maxHeight)),
        ),
      ),
    );
  }
}
