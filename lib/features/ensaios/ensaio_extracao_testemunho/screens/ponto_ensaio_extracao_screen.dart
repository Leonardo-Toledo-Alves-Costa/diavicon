import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/extracao_model.dart';
import '../repositories/extracao_repository.dart';
import '../widgets/croqui_extracao.dart';
import '../widgets/novo_ponto_extracao_modal.dart';
import 'analise_ponto_extracao_screen.dart';

/// Tela de coleta do ensaio de Extração e Rompimento de Testemunho —
/// diferente dos demais ensaios (1 por elemento), este é 1 ensaio por LOCAL,
/// com múltiplos pontos de extração (testemunhos) marcados na planta, cada
/// um com seu próprio elemento estrutural. O gráfico de resistência
/// corrigida e o de fck ficam na tela de Análise, acessível pelo drawer.
class PontoEnsaioExtracaoScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;

  const PontoEnsaioExtracaoScreen({super.key, required this.pontoGeralId});

  @override
  ConsumerState<PontoEnsaioExtracaoScreen> createState() => _PontoEnsaioExtracaoScreenState();
}

class _PontoEnsaioExtracaoScreenState extends ConsumerState<PontoEnsaioExtracaoScreen> {
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isEditingName = false;
  bool _plantaExpandida = true;
  final GlobalKey _croquiRepaintKey = GlobalKey();

  late final TextEditingController _nomeCtrl;
  ExtracaoLocalModel? _local;
  String? _localNome;
  String? _plantaUrl;
  ImageProvider? _plantaImagem;
  String? _estruturaId;
  String? _tipoEnsaioId;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  List<LeituraExtracaoModel> get _pontosOrdenados => _local?.leiturasOrdenadas ?? const [];

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(extracaoRepositoryProvider);
      final geral = await repo.buscarDadosGerais(widget.pontoGeralId);
      _nomeCtrl.text = geral['nomePonto'] ?? '';
      _estruturaId = geral['estruturaId'];
      _tipoEnsaioId = geral['tipoEnsaioId'];

      _local = await repo.buscarPontoExtracao(widget.pontoGeralId);
      if (_local != null) {
        _localNome = await repo.resolverNomeLocal(_local!.localId);
        _plantaUrl = await repo.resolverPlantaUrl(_local!.plantaId);
        if (_plantaUrl != null && _plantaUrl!.isNotEmpty && !_plantaUrl!.toLowerCase().contains('.pdf')) {
          _plantaImagem = StorageNetworkImage(_plantaUrl!);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _renomear() async {
    setState(() => _isEditingName = false);
    try {
      await ref.read(extracaoRepositoryProvider).renomearPonto(pontoGeralId: widget.pontoGeralId, nome: _nomeCtrl.text.trim());
      ref.invalidate(resumoEnsaiosProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao renomear: $e'), backgroundColor: Colors.red));
    }
  }

  Future<File?> _capturarPlantaMarcada() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _croquiRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final file = File('${Directory.systemTemp.path}/extracao_marcada_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      return file;
    } catch (e) {
      debugPrint('Erro ao capturar planta marcada: $e');
      return null;
    }
  }

  Future<void> _abrirNovoPonto({LeituraExtracaoModel? leituraExistente}) async {
    if (_local == null || _estruturaId == null || _localNome == null || _plantaUrl == null) return;

    final numeroVisual = leituraExistente != null ? _pontosOrdenados.indexWhere((p) => p.id == leituraExistente.id) + 1 : _pontosOrdenados.length + 1;

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => NovoPontoExtracaoModal(
        estruturaId: _estruturaId!,
        localNome: _localNome!,
        plantaUrl: _plantaUrl!,
        pontosExistentes: _pontosOrdenados,
        leituraExistente: leituraExistente,
        numeroVisual: numeroVisual,
      ),
    );
    if (resultado == null) return;

    setState(() => _isLoading = true);
    try {
      final leitura = LeituraExtracaoModel(
        id: leituraExistente?.id,
        pontoLocalId: _local!.id,
        elementoId: resultado['elementoId'] as String,
        criadoEm: leituraExistente?.criadoEm,
        nomeTestemunho: resultado['nomeTestemunho'] as String,
        posX: resultado['posX'] as double,
        posY: resultado['posY'] as double,
        fotoExtraindo: leituraExistente?.fotoExtraindo,
        fotoExtracao: leituraExistente?.fotoExtracao,
        fotoRecomposicao: leituraExistente?.fotoRecomposicao,
        direcao: resultado['direcao'] as DirecaoExtracao,
        relacaoHD: resultado['relacaoHD'] as double,
        diametroTestemunho: resultado['diametroTestemunho'] as double,
        condicaoUmidade: resultado['condicaoUmidade'] as CondicaoUmidade,
        resistenciaSemCorrecao: resultado['resistenciaSemCorrecao'] as double,
      );

      await ref.read(extracaoRepositoryProvider).salvarLeitura(
            localAtual: _local!,
            leitura: leitura,
            fotoExtraindoNova: resultado['fotoExtraindo'] as File?,
            fotoExtracaoNova: resultado['fotoExtracao'] as File?,
            fotoRecomposicaoNova: resultado['fotoRecomposicao'] as File?,
            fotoPlantaNova: resultado['fotoPlanta'] as File?,
          );

      await _carregarDados();
      await _recapturarPlantaCompleta();

      ref.invalidate(resumoEnsaiosProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto salvo!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Recaptura a planta com TODOS os pontos marcados — chamada tanto ao
  // adicionar quanto ao excluir um ponto, pra `planta_marcada` nunca ficar
  // desatualizada. Garante a seção "Planta" expandida (senão o
  // RepaintBoundary não está montado e a captura falha silenciosamente).
  Future<void> _recapturarPlantaCompleta() async {
    if (_local?.id == null) return;
    if (!_plantaExpandida) {
      setState(() => _plantaExpandida = true);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    final imagemComposta = await _capturarPlantaMarcada();
    if (imagemComposta != null) {
      await ref.read(extracaoRepositoryProvider).salvarImagemComposta(pontoGeralId: widget.pontoGeralId, pontoLocalId: _local!.id!, imagem: imagemComposta);
    }
  }

  Future<void> _excluirPonto(LeituraExtracaoModel leitura) async {
    if (leitura.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ponto de extração'),
        content: const Text('Deseja realmente excluir este ponto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(extracaoRepositoryProvider).deletarLeitura(leitura.id!);
      await _carregarDados();
      await _recapturarPlantaCompleta();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirEnsaio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ensaio'),
        content: const Text('Deseja realmente excluir este ensaio de extração e todos os seus pontos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(extracaoRepositoryProvider).deletarPontoCompleto(widget.pontoGeralId);
      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ensaio excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final permissoes = ref.watch(ensaioPermissoesProvider(widget.pontoGeralId)).value ?? EnsaioPermissoes.somenteVisualizar;
    final pontos = _pontosOrdenados;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: MenuDrawerAppBar(
        title: 'Ensaio de\nExtração',
        items: [
          DiaviconMenuItem(
            icon: Icons.show_chart,
            label: 'Análise',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => AnalisePontoExtracaoScreen(pontoGeralId: widget.pontoGeralId, localNome: _localNome ?? '-')));
            },
          ),
          DiaviconMenuItem(
            icon: Icons.camera_alt_outlined,
            label: 'Fotos',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(MaterialPageRoute(
                builder: (context) => GaleriaEnsaioScreen(
                  pontoGeralId: widget.pontoGeralId,
                  pontoNome: _nomeCtrl.text,
                  elementoNome: _nomeCtrl.text,
                  tipoElemento: 'Extração e Rompimento de Testemunho',
                  local: _localNome ?? '-',
                  tipoEnsaio: _tipoEnsaioId ?? '',
                ),
              ));
            },
          ),
          const Spacer(),
          const Divider(),
          if (permissoes.canDelete)
            IconButton(
              iconSize: 30,
              color: Colors.red.shade800,
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.pop(context);
                _excluirEnsaio();
              },
            ),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Extração de testemunho', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Ponto de ensaio', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarDados,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!permissoes.canEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                    ],
                  ),
                ),
              AbsorbPointer(
                absorbing: !permissoes.canEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _isEditingName
                              ? TextField(controller: _nomeCtrl, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold), onSubmitted: (_) => _renomear())
                              : Text(_nomeCtrl.text, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        ),
                        if (permissoes.canEdit)
                          IconButton(
                            icon: Icon(_isEditingName ? Icons.check : Icons.edit_square, size: 20, color: const Color(0xFF3E3E3D)),
                            onPressed: () => _isEditingName ? _renomear() : setState(() => _isEditingName = true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() => _plantaExpandida = !_plantaExpandida),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text('Planta', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                      const SizedBox(width: 8),
                                      Text(_localNome ?? '-', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  Icon(_plantaExpandida ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                          if (_plantaExpandida)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: RepaintBoundary(
                                key: _croquiRepaintKey,
                                child: CroquiExtracao(
                                  imagem: _plantaImagem,
                                  pontosOrdenados: pontos,
                                  onTapPonto: permissoes.canEdit ? (p) => _abrirNovoPonto(leituraExistente: p) : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (permissoes.canEdit)
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _abrirNovoPonto(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: Text('Novo ponto de extração', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    const SizedBox(height: 24),
                    Text('Pontos registrados', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    const SizedBox(height: 8),
                    if (pontos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nenhum ponto registrado ainda.', style: GoogleFonts.lato(color: Colors.grey))),
                      )
                    else
                      ...pontos.asMap().entries.map((entry) => _buildCardPonto(entry.key + 1, entry.value, permissoes)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPonto(int numero, LeituraExtracaoModel p, EnsaioPermissoes permissoes) {
    return InkWell(
      onTap: permissoes.canEdit ? () => _abrirNovoPonto(leituraExistente: p) : null,
      onLongPress: permissoes.canDelete ? () => _excluirPonto(p) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Center(child: Text('$numero', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.nomeTestemunho} · ${p.elementoNome}', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  Text(_localNome ?? '-', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text(
              p.resistenciaComCorrecao != null ? '${p.resistenciaComCorrecao!.toStringAsFixed(1)} MPa' : '—',
              style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
            ),
          ],
        ),
      ),
    );
  }
}
