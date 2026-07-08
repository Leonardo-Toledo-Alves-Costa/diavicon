import 'dart:io';
import 'package:diavicon/features/elementos/providers/info_planejamento_provider.dart';
import 'package:diavicon/features/ensaios/models/regiao_ensaio_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/widgets/marcacao_planta_popup.dart'; 


class NovaRegiaoEnsaioModal extends ConsumerStatefulWidget {
  final String estruturaId, plantaId, plantaUrl, empresaId, empresaNome;
  final String? empresaFotoUrl;
  final double posicaoX, posicaoY, larguraMarcacao, alturaMarcacao, rotacaoMarcacao;
  final String tipoMarcacao;
  final int numeroMarcacao;
  final String corMarcacao;
  final RegiaoEnsaioModel? regiao; 
  final String? inicialDescricao, inicialElementoId;

  const NovaRegiaoEnsaioModal({
    super.key, required this.estruturaId, required this.plantaId, required this.plantaUrl, required this.empresaId, required this.empresaNome, this.empresaFotoUrl,
    required this.posicaoX, required this.posicaoY, required this.larguraMarcacao, required this.alturaMarcacao, required this.rotacaoMarcacao, required this.tipoMarcacao, required this.numeroMarcacao, required this.corMarcacao,
    this.regiao, this.inicialDescricao, this.inicialElementoId,
  });

  @override
  ConsumerState<NovaRegiaoEnsaioModal> createState() => _NovaRegiaoEnsaioModalState();
}

class _NovaRegiaoEnsaioModalState extends ConsumerState<NovaRegiaoEnsaioModal> {
  final _descricaoController = TextEditingController();
  String? _elementoSelecionadoId;
  int _abaSelecionada = 0; 
  bool _isLoadingSalvar = false, _isPdf = false, _isLoadingMidia = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState(); _carregarMidia();
    if (widget.inicialDescricao != null) { _descricaoController.text = widget.inicialDescricao!; } else if (widget.regiao != null) { _descricaoController.text = widget.regiao!.descricao ?? ''; }
    if (widget.inicialElementoId != null) { _elementoSelecionadoId = widget.inicialElementoId; } else if (widget.regiao != null) { _elementoSelecionadoId = widget.regiao!.elementoId; }
  }

  @override
  void dispose() { _descricaoController.dispose(); super.dispose(); }

  // 🔥 IGUALADO À TELA PRINCIPAL (maxDim = 2500) PARA O TAMANHO NÃO MUDAR!
  Future<void> _carregarMidia() async {
    if (widget.plantaUrl.isEmpty) return;
    if (widget.plantaUrl.toLowerCase().contains('.pdf')) {
      setState(() { _isPdf = true; _isLoadingMidia = true; });
      try {
        final req = await HttpClient().getUrl(Uri.parse(widget.plantaUrl));
        final doc = await PdfDocument.openData(await consolidateHttpClientResponseBytes(await req.close()));
        final page = await doc.getPage(1);
        double w = page.width; double h = page.height;
        if (w < 800) { w *= 2.0; h *= 2.0; }
        const maxDim = 2500.0;
        if (w > maxDim || h > maxDim) {
          final prop = w / h;
          if (w > h) { w = maxDim; h = maxDim / prop; } else { h = maxDim; w = maxDim * prop; }
        }
        final pageImg = await page.render(width: w, height: h, format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF');
        if (pageImg != null && mounted) setState(() => _imageBytes = pageImg.bytes);
        await page.close(); await doc.close();
      } catch (e) { debugPrint('Erro PDF: $e'); } finally { if (mounted) setState(() => _isLoadingMidia = false); }
    }
  }

  void _salvarRegiao() async {
    if (_elementoSelecionadoId == null) { DiaviconAlerts.show(context, 'Campo Obrigatório', 'Selecione a qual Elemento Estrutural esta região pertence.', isErro: true); return; }
    setState(() => _isLoadingSalvar = true);
    try {
      final supabase = Supabase.instance.client;
      final dados = {
        'planta_id': widget.plantaId, 'empresa_id': widget.empresaId, 'elemento_id': _elementoSelecionadoId,
        'numero': widget.numeroMarcacao, 'posicao_x': widget.posicaoX, 'posicao_y': widget.posicaoY,
        'tipo_marcacao': widget.tipoMarcacao, 'marcacao_largura': widget.larguraMarcacao, 'marcacao_altura': widget.alturaMarcacao, 'marcacao_rotacao': widget.rotacaoMarcacao,
        'tamanho_marcacao': 30.0, 'cor_marcacao': widget.corMarcacao, 'descricao': _descricaoController.text.trim(),
      };
      if (widget.regiao != null) { await supabase.from('regioes_ensaio').update(dados).eq('id', widget.regiao!.id).select().single(); } 
      else { dados['criado_por'] = supabase.auth.currentUser?.id; await supabase.from('regioes_ensaio').insert(dados).select().single(); }
      
      if (!mounted) return;
      ref.invalidate(regioesEnsaioProvider(RegioesFiltro(plantaId: widget.plantaId, empresaId: widget.empresaId)));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.regiao != null ? 'Atualizado com sucesso!' : 'Criado com sucesso!'), backgroundColor: const Color(0xFF238E5A), behavior: SnackBarBehavior.floating));
      Navigator.of(context).pop({'acao': 'salvo'}); 
    } catch (e) { if (mounted) DiaviconAlerts.show(context, 'Erro', 'Falha ao salvar: $e', isErro: true); } finally { if (mounted) setState(() => _isLoadingSalvar = false); }
  }

  void _apagarRegiao() async {
    if (widget.regiao == null) { Navigator.pop(context, {'acao': 'cancelar'}); return; }
    setState(() => _isLoadingSalvar = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('regioes_ensaio').delete().eq('id', widget.regiao!.id);
      if (!mounted) return;
      ref.invalidate(regioesEnsaioProvider(RegioesFiltro(plantaId: widget.plantaId, empresaId: widget.empresaId)));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Região removida!'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
      Navigator.pop(context, {'acao': 'deletado'});
    } catch (e) { if (mounted) DiaviconAlerts.show(context, 'Erro', 'Falha ao apagar: $e', isErro: true); } finally { if (mounted) setState(() => _isLoadingSalvar = false); }
  }

  @override
  Widget build(BuildContext context) {
    final elementosAsync = ref.watch(elementosPorEstruturaProvider(widget.estruturaId));
    final regioesAsync = ref.watch(regioesEnsaioProvider(RegioesFiltro(plantaId: widget.plantaId, empresaId: widget.empresaId))); 
    final corPino = Color(int.parse(widget.corMarcacao.replaceFirst('#', '0xff')));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        height: MediaQuery.of(context).size.height * 0.85, 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 48, height: 5, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(widget.regiao != null ? 'Editar região de ensaio' : 'Nova região de ensaio', style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 22, fontWeight: FontWeight.w900))),
                  GestureDetector(onTap: () => Navigator.pop(context, {'acao': 'cancelar'}), child: const Icon(Icons.close, color: AppColors.greyMedium, size: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200, width: 1.5)), child: CircleAvatar(radius: 20, backgroundColor: Colors.white, backgroundImage: (widget.empresaFotoUrl != null && widget.empresaFotoUrl!.isNotEmpty) ? NetworkImage(widget.empresaFotoUrl!) : null, child: (widget.empresaFotoUrl == null || widget.empresaFotoUrl!.isEmpty) ? const Icon(Icons.business, color: AppColors.primary) : null)),
                  const SizedBox(width: 12),
                  Text(widget.empresaNome, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF3E3E3D))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(24)), child: Row(children: [Expanded(child: _buildTabButton('Informações', 0)), Expanded(child: _buildTabButton('Ensaios', 1))])),
            ),
            const SizedBox(height: 24),
            Expanded(child: _abaSelecionada == 0 ? _buildAbaInformacoes(elementosAsync, regioesAsync, corPino) : const Center(child: Text('Aba de Ensaios em construção...'))),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    Expanded(child: CompactButton(text: 'Apagar', height: 52, backgroundColor: Colors.white, foregroundColor: AppColors.error, borderColor: AppColors.error, elevation: 0, onPressed: _apagarRegiao)),
                    const SizedBox(width: 16),
                    Expanded(child: _isLoadingSalvar ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : CompactButton(text: 'Salvar', height: 52, onPressed: _salvarRegiao)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String titulo, int index) {
    final isSelected = _abaSelecionada == index;
    return GestureDetector(onTap: () => setState(() => _abaSelecionada = index), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(24)), alignment: Alignment.center, child: Text(titulo, style: GoogleFonts.lato(fontSize: 15, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF686868)))));
  }

  Widget _buildAbaInformacoes(AsyncValue<List<dynamic>> elementosAsync, AsyncValue<List<dynamic>> regioesAsync, Color corPino) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          elementosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()), error: (err, _) => Text('Erro: $err', style: const TextStyle(color: Colors.red)),
            data: (elementos) {
              final items = elementos.map((el) => DropdownMenuItem<String>(value: el.id, child: Text('${el.tipo ?? 'Elemento'} - ${el.nome ?? ''}'))).toList();
              return CustomDropdownWithAdd<String>(label: 'Elemento Estrutural *', hint: 'Selecione', value: _elementoSelecionadoId, items: items, onChanged: (val) => setState(() => _elementoSelecionadoId = val), onAddPressed: () => DiaviconAlerts.show(context, 'Adicionar', 'Crie na aba Elementos.', isAviso: true), isRequired: true);
            },
          ),
          const SizedBox(height: 24),
          Container(
            height: 160,
            decoration: BoxDecoration(color: AppColors.greyVeryLight, border: Border.all(color: AppColors.inputBorder, width: 1.5), borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.hardEdge, 
            child: _isLoadingMidia
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : InteractiveViewer(
                    minScale: 0.1, maxScale: 3.0,
                    child: Center(
                      child: Stack(
                        children: [
                          _isPdf ? (_imageBytes != null ? Image.memory(_imageBytes!) : const SizedBox()) : Image.network(widget.plantaUrl),
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth; final h = constraints.maxHeight;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (regioesAsync.value != null)
                                      ...regioesAsync.value!.map((reg) {
                                        if (widget.regiao != null && reg.id == widget.regiao!.id) return const SizedBox();
                                        final cx = reg.posicaoX * w; final cy = reg.posicaoY * h;
                                        final wPino = reg.marcacaoLargura * w; final hPino = reg.marcacaoAltura * h;
                                        final corAntiga = Color(int.parse(reg.corMarcacao.replaceFirst('#', '0xff')));
                                        return Positioned(left: cx - (wPino / 2), top: cy - (hPino / 2), child: Stack(alignment: Alignment.center, children: [Opacity(opacity: 0.4, child: PinoDinamico(tipoMarcacao: reg.tipoMarcacao, largura: wPino, altura: hPino, rotacao: reg.marcacaoRotacao, corBase: corAntiga, mostrarNumero: false)), Opacity(opacity: 0.8, child: Text(reg.numero.toString(), style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))]));
                                      }),

                                    Positioned(
                                      left: (widget.posicaoX * w) - ((widget.larguraMarcacao * w) / 2), top: (widget.posicaoY * h) - ((widget.alturaMarcacao * h) / 2),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          PinoDinamico(tipoMarcacao: widget.tipoMarcacao, largura: widget.larguraMarcacao * w, altura: widget.alturaMarcacao * h, rotacao: widget.rotacaoMarcacao, corBase: corPino.withOpacity(0.85), mostrarNumero: false),
                                          Text('${widget.numeroMarcacao}', style: GoogleFonts.lato(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black45, blurRadius: 2)])),
                                        ],
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
          const SizedBox(height: 16),
          Align(alignment: Alignment.center, child: CompactButton(text: 'Editar Local', height: 40, width: 160, backgroundColor: AppColors.primary, onPressed: () => Navigator.pop(context, {'acao': 'editar', 'descricao': _descricaoController.text, 'elementoId': _elementoSelecionadoId}))),
          const SizedBox(height: 32),
          CustomTextField(label: 'Descrição da região de ensaio', hint: 'Descrição...', controller: _descricaoController, maxLines: 4),
        ],
      ),
    );
  }
}