import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/diavicon_alerts.dart';
import '../../../elementos/widgets/marcacao_planta_popup.dart' show PinoDinamico;
import '../models/ponto_prova_carga_model.dart';
import '../providers/prova_carga_providers.dart';
import '../screens/ponto_ensaio_prova_carga_screen.dart';

/// Marca a "Área de Ensaio" (um retângulo) na planta. Usado tanto na
/// criação (passo 2, encadeado por `NovoEnsaioProvaCargaModal`) quanto na
/// reedição, a partir do botão "Área de Ensaio" da tela principal.
///
/// Em modo criação ([areaExistente] nulo), grava direto no Supabase e
/// navega para a tela do ensaio. Em modo edição, só devolve o modelo
/// atualizado via `Navigator.pop` — quem persiste é a tela principal, no
/// "Salvar Informações" (mesmo padrão do resto do ensaio).
class SelecionarAreaEnsaioModal extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;
  final String tipoEnsaioId;
  final String nomeInicial;
  final String plantaUrl;
  final String? elementoId;
  final PontoProvaCargaModel? areaExistente;

  const SelecionarAreaEnsaioModal({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    required this.tipoEnsaioId,
    required this.nomeInicial,
    required this.plantaUrl,
    this.elementoId,
    this.areaExistente,
  });

  @override
  ConsumerState<SelecionarAreaEnsaioModal> createState() => _SelecionarAreaEnsaioModalState();
}

class _SelecionarAreaEnsaioModalState extends ConsumerState<SelecionarAreaEnsaioModal> {
  late final TextEditingController _nomeController;
  bool get _isEdicao => widget.areaExistente != null;

  bool _isPdf = false;
  bool _isLoadingMidia = false;
  bool _isSalvando = false;
  Uint8List? _imageBytes;

  late Offset _posicao;
  late double _largura;
  late double _altura;
  late double _rotacao;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.nomeInicial);
    final area = widget.areaExistente;
    _posicao = Offset(area?.marcaX ?? 0.5, area?.marcaY ?? 0.5);
    _largura = area?.marcaLargura ?? 0.3;
    _altura = area?.marcaAltura ?? 0.3;
    _rotacao = area?.marcaRotacao ?? 0.0;
    _carregarMidia();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _carregarMidia() async {
    if (widget.plantaUrl.toLowerCase().contains('.pdf')) {
      setState(() {
        _isPdf = true;
        _isLoadingMidia = true;
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
        if (mounted) setState(() => _isLoadingMidia = false);
      }
    }
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      DiaviconAlerts.show(context, 'Campo obrigatório', 'Informe o nome da área de ensaio.', isErro: true);
      return;
    }

    final area = (widget.areaExistente ?? PontoProvaCargaModel(nome: nome)).copyWith(
      nome: nome,
      elementoId: widget.elementoId,
      plantaFoto: widget.plantaUrl,
      marcaX: _posicao.dx,
      marcaY: _posicao.dy,
      marcaLargura: _largura,
      marcaAltura: _altura,
      marcaRotacao: _rotacao,
      marcaForma: 'Retângulo',
    );

    if (_isEdicao) {
      Navigator.pop(context, area);
      return;
    }

    setState(() => _isSalvando = true);
    try {
      final resultado = await ref.read(provaCargaRepositoryProvider).criarAreaInicial(
            projetoId: widget.projetoId,
            estruturaId: widget.estruturaId,
            tipoEnsaioId: widget.tipoEnsaioId,
            area: area,
          );

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PontoEnsaioProvaCargaScreen(pontoGeralId: resultado['pontoGeralId']!),
        ),
      );
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Falha ao criar área de ensaio: $e', isErro: true);
        setState(() => _isSalvando = false);
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
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Selecione o local na planta',
                    style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
              ],
            ),
          ),

          if (!_isEdicao)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CustomTextField(label: 'Nome da área de ensaio', hint: 'Nome', controller: _nomeController, isRequired: true),
            ),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9))),
              child: _isLoadingMidia
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Center(
                        child: Stack(
                          children: [
                            _isPdf
                                ? (_imageBytes != null ? Image.memory(_imageBytes!) : const SizedBox())
                                : ImagemStorage.network(widget.plantaUrl),
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
                                          onTapUp: (details) => setState(() => _posicao = Offset(
                                                (details.localPosition.dx / w).clamp(0.0, 1.0),
                                                (details.localPosition.dy / h).clamp(0.0, 1.0),
                                              )),
                                        ),
                                      ),
                                      Positioned(
                                        left: (_posicao.dx * w) - ((_largura * w) / 2),
                                        top: (_posicao.dy * h) - ((_altura * h) / 2),
                                        child: GestureDetector(
                                          onPanUpdate: (details) => setState(() => _posicao = Offset(
                                                (_posicao.dx + (details.delta.dx / w)).clamp(0.0, 1.0),
                                                (_posicao.dy + (details.delta.dy / h)).clamp(0.0, 1.0),
                                              )),
                                          child: PinoDinamico(
                                            tipoMarcacao: 'Retângulo',
                                            largura: _largura * w,
                                            altura: _altura * h,
                                            rotacao: _rotacao,
                                            corBase: AppColors.primary,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Largura', style: GoogleFonts.lato(fontSize: 12)),
                            Slider(value: _largura, min: 0.05, max: 0.9, activeColor: AppColors.primary, onChanged: (v) => setState(() => _largura = v)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Altura', style: GoogleFonts.lato(fontSize: 12)),
                            Slider(value: _altura, min: 0.05, max: 0.9, activeColor: AppColors.primary, onChanged: (v) => setState(() => _altura = v)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rotação', style: GoogleFonts.lato(fontSize: 12)),
                            Slider(value: _rotacao, min: 0.0, max: 360.0, activeColor: AppColors.primary, onChanged: (v) => setState(() => _rotacao = v)),
                          ],
                        ),
                      ),
                      CompactButton(
                        text: _isSalvando ? '...' : 'Salvar',
                        width: 100,
                        onPressed: _isSalvando ? () {} : _salvar,
                      ),
                    ],
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
