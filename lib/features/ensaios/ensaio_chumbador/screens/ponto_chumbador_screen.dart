import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/chumbador_model.dart';
import '../repositories/chumbador_repository.dart';
import '../widgets/nova_leitura_chumbador_modal.dart';
import 'analise_ponto_chumbador_screen.dart';
import '../../../../core/web/escolher_foto.dart';

// Tela de coleta do ensaio de Tração em Chumbador — dados gerais (fotos,
// ocorrências, condição de avaliação) sempre editáveis + lista de leituras
// na MESMA tela, mesmo padrão do resto do app (Potencial/Monitoramento de
// Fissuras: um formulário só, sem etapa "criar" separada de "coletar"). O
// gráfico força×deslocamento e os cards de carga máxima/deslocamento máximo
// ficam na tela de Análise, acessível pelo drawer.
class PontoChumbadorScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoChumbadorScreen({
    super.key,
    required this.projetoId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.elementoId,
    this.pontoGeralId,
    required this.tipoEnsaioId,
  });

  @override
  ConsumerState<PontoChumbadorScreen> createState() => _PontoChumbadorScreenState();
}

class _PontoChumbadorScreenState extends ConsumerState<PontoChumbadorScreen> {
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isEditingName = false;

  String? _pontoGeralIdAtual;
  String? _ensaioId;
  List<LeituraChumbadorModel> _leituras = [];

  late final TextEditingController _nomeCtrl;
  final _ocorrenciasCtrl = TextEditingController();
  CondicaoAvaliacaoChumbador? _condicaoSelecionada;
  File? _fotoChumbadorLocal, _fotoDuranteLocal, _fotoAposLocal;
  String? _urlFotoChumbador, _urlFotoDurante, _urlFotoApos;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.pontoNome);
    _pontoGeralIdAtual = (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) ? widget.pontoGeralId : null;
    if (_pontoGeralIdAtual == null) _hasChanges = true;
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _ocorrenciasCtrl.dispose();
    super.dispose();
  }

  ChumbadorModel get _ensaioAtual => ChumbadorModel(
        id: _ensaioId,
        pontoGeralId: _pontoGeralIdAtual,
        fotoChumbador: _urlFotoChumbador,
        fotoDurante: _urlFotoDurante,
        fotoApos: _urlFotoApos,
        ocorrenciasGerais: _ocorrenciasCtrl.text,
        condicaoAvaliacao: _condicaoSelecionada,
        leituras: _leituras,
      );

  List<LeituraChumbadorModel> get _leiturasOrdenadas => _ensaioAtual.leiturasOrdenadas;

  Future<void> _carregarDados() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }
    try {
      final ensaio = await ref.read(chumbadorRepositoryProvider).buscarPontoChumbador(_pontoGeralIdAtual!);
      if (ensaio != null) {
        _ensaioId = ensaio.id;
        _urlFotoChumbador = ensaio.fotoChumbador;
        _urlFotoDurante = ensaio.fotoDurante;
        _urlFotoApos = ensaio.fotoApos;
        _ocorrenciasCtrl.text = ensaio.ocorrenciasGerais;
        _condicaoSelecionada = ensaio.condicaoAvaliacao;
        _leituras = ensaio.leituras;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isInitializing = false; _hasChanges = false; });
    }
  }

  void _onCampoAlterado() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<File?> _escolherFoto() async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
    if (source == null) return null;
    final imagem = await ImagePicker().pickImage(source: source, imageQuality: 80);
    return imagem != null ? File(imagem.path) : null;
  }

  Future<void> _salvarPonto() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarPonto`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer. Como
    // o repositório decide INSERT vs UPDATE em `pontos_ensaios_geral` e
    // `ponto_ensaio_tracao` a partir de `_pontoGeralIdAtual`/`_ensaioId`
    // (nulos pra um ponto novo), as duas chamadas cairiam no ramo de INSERT
    // e duplicariam as linhas. Setar `_isLoading` aqui é síncrono (setState
    // muda o campo na hora, só o rebuild é adiado), então a segunda chamada
    // já vê `_isLoading == true` e sai antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final res = await ref.read(chumbadorRepositoryProvider).salvarPonto(
            dados: _ensaioAtual,
            projetoId: widget.projetoId,
            elementoId: widget.elementoId,
            tipoEnsaioId: widget.tipoEnsaioId,
            pontoNome: _nomeCtrl.text.trim(),
            fotoChumbadorNova: _fotoChumbadorLocal,
            fotoDuranteNova: _fotoDuranteLocal,
            fotoAposNova: _fotoAposLocal,
          );
      _pontoGeralIdAtual = res['pontoGeralId'] as String;
      _fotoChumbadorLocal = null;
      _fotoDuranteLocal = null;
      _fotoAposLocal = null;
      ref.invalidate(resumoEnsaiosProvider);
      await _carregarDados();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirNovaLeitura({LeituraChumbadorModel? leituraExistente}) async {
    if (_pontoGeralIdAtual == null || _hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve os dados gerais primeiro.'), backgroundColor: Colors.orange));
      return;
    }

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => NovaLeituraChumbadorModal(leituraExistente: leituraExistente),
    );
    if (resultado == null) return;

    setState(() => _isLoading = true);
    try {
      final leitura = LeituraChumbadorModel(
        id: leituraExistente?.id,
        ensaioId: _ensaioId,
        criadoEm: leituraExistente?.criadoEm,
        etapa: resultado['etapa'] as EtapaLeituraChumbador,
        forcaKn: resultado['forcaKn'] as double,
        deslocamentoMm: resultado['deslocamentoMm'] as double,
        foto: leituraExistente?.foto,
        ocorrencia: resultado['ocorrencia'] as String,
      );

      await ref.read(chumbadorRepositoryProvider).salvarLeitura(
            pontoGeralId: _pontoGeralIdAtual!,
            ensaioAtual: _ensaioAtual,
            leitura: leitura,
            fotoNova: resultado['foto'] as File?,
          );
      ref.invalidate(resumoEnsaiosProvider);
      await _carregarDados();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leitura salva!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirLeitura(LeituraChumbadorModel leitura) async {
    if (_pontoGeralIdAtual == null || leitura.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir leitura'),
        content: const Text('Deseja realmente excluir esta leitura?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(chumbadorRepositoryProvider).deletarLeitura(pontoGeralId: _pontoGeralIdAtual!, ensaioAtual: _ensaioAtual, leituraId: leitura.id!);
      ref.invalidate(resumoEnsaiosProvider);
      await _carregarDados();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirPonto() async {
    if (_pontoGeralIdAtual == null) {
      Navigator.pop(context);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ponto'),
        content: const Text('Deseja realmente excluir este ponto de ensaio e todas as suas leituras?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(chumbadorRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
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

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralIdAtual ?? '')).value ?? EnsaioPermissoes.somenteVisualizar;
    final leituras = _leiturasOrdenadas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _pontoGeralIdAtual == null
          ? null
          : MenuDrawerAppBar(
              title: 'Ponto de\nEnsaio',
              items: [
                DiaviconMenuItem(
                  icon: Icons.show_chart,
                  label: 'Análise',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (_pontoGeralIdAtual == null || _hasChanges) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve os dados gerais primeiro.'), backgroundColor: Colors.orange));
                      return;
                    }
                    navigator.push(MaterialPageRoute(
                      builder: (context) => AnalisePontoChumbadorScreen(
                        pontoGeralId: _pontoGeralIdAtual!,
                        pontoNome: _nomeCtrl.text,
                        elementoNome: widget.elementoNome,
                        tipoElemento: widget.tipoElemento,
                        local: widget.local,
                      ),
                    ));
                  },
                ),
                DiaviconMenuItem(
                  icon: Icons.camera_alt_outlined,
                  label: 'Fotos',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (_pontoGeralIdAtual == null || _hasChanges) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve os dados gerais primeiro.'), backgroundColor: Colors.orange));
                      return;
                    }
                    navigator.push(MaterialPageRoute(
                      builder: (context) => GaleriaEnsaioScreen(
                        pontoGeralId: _pontoGeralIdAtual!,
                        pontoNome: _nomeCtrl.text,
                        elementoNome: widget.elementoNome,
                        tipoElemento: widget.tipoElemento,
                        local: widget.local,
                        tipoEnsaio: widget.tipoEnsaioId,
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
                      _excluirPonto();
                    },
                  ),
              ],
            ),
      appBar: CustomAppBar(
        title: 'Tração em Chumbador',
        showBackButton: true,
        showMenuButton: _pontoGeralIdAtual != null,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ponto de ensaio', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('${widget.pontoNome} - ${widget.elementoNome}', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
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
                    _buildCardDadosGerais(),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Leituras', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        if (permissoes.canEdit)
                          TextButton.icon(
                            onPressed: _isLoading ? null : () => _abrirNovaLeitura(),
                            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                            label: Text('Nova leitura', style: GoogleFonts.lato(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (leituras.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nenhuma leitura registrada ainda.', style: GoogleFonts.lato(color: Colors.grey))),
                      )
                    else
                      ...leituras.reversed.map((l) => _buildCardLeitura(l, permissoes)),
                    const SizedBox(height: 24),
                    _buildCardCondicaoAvaliacao(),
                    if (_hasChanges && permissoes.canEdit) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _salvarPonto,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Salvar dados gerais', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDadosGerais() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _isEditingName
                    ? TextField(
                        controller: _nomeCtrl,
                        style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                        onChanged: (_) => _onCampoAlterado(),
                        onSubmitted: (_) => setState(() => _isEditingName = false),
                      )
                    : Text(_nomeCtrl.text, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              ),
              IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square, size: 20, color: const Color(0xFF3E3E3D)), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
            ],
          ),
          Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
          Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Text('Fotos', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildCardFoto('Chumbador', _fotoChumbadorLocal, _urlFotoChumbador, () async {
                final f = await _escolherFoto();
                if (f != null) setState(() { _fotoChumbadorLocal = f; _onCampoAlterado(); });
              })),
              const SizedBox(width: 10),
              Expanded(child: _buildCardFoto('Durante', _fotoDuranteLocal, _urlFotoDurante, () async {
                final f = await _escolherFoto();
                if (f != null) setState(() { _fotoDuranteLocal = f; _onCampoAlterado(); });
              })),
              const SizedBox(width: 10),
              Expanded(child: _buildCardFoto('Após', _fotoAposLocal, _urlFotoApos, () async {
                final f = await _escolherFoto();
                if (f != null) setState(() { _fotoAposLocal = f; _onCampoAlterado(); });
              })),
            ],
          ),
          const SizedBox(height: 16),
          Text('Ocorrências gerais', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          TextField(
            controller: _ocorrenciasCtrl,
            maxLines: 3,
            onChanged: (_) => _onCampoAlterado(),
            decoration: InputDecoration(hintText: 'Ex: Fixação em concreto C30, sem fissuras aparentes antes do ensaio...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  // Condição de avaliação é a conclusão do ensaio (depois de ver as
  // leituras) — fica no fim da tela, depois da lista de leituras, não junto
  // dos dados gerais do topo.
  Widget _buildCardCondicaoAvaliacao() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Condição de avaliação', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 12),
          Row(
            children: CondicaoAvaliacaoChumbador.values.map((c) {
              final selecionado = _condicaoSelecionada == c;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c != CondicaoAvaliacaoChumbador.values.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() { _condicaoSelecionada = c; _onCampoAlterado(); }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selecionado ? c.cor.withValues(alpha: 0.15) : Colors.transparent,
                        border: Border.all(color: selecionado ? c.cor : const Color(0xFF9E9E9E)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c.label, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: selecionado ? c.cor : Colors.grey.shade700)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFoto(String titulo, File? localFile, String? url, VoidCallback onTap) {
    ImageProvider? img;
    if (localFile != null) {
      img = FileImage(localFile);
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
          raio: 12,
          aoTocar: onTap,
          vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 24)),
          acao: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.edit_square, size: 12, color: Color(0xFF3E3E3D)),
          ),
        ),
      ],
    );
  }

  Widget _buildCardLeitura(LeituraChumbadorModel leitura, EnsaioPermissoes permissoes) {
    return InkWell(
      onTap: permissoes.canEdit ? () => _abrirNovaLeitura(leituraExistente: leitura) : null,
      onLongPress: permissoes.canDelete ? () => _excluirLeitura(leitura) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                image: leitura.foto != null && leitura.foto!.isNotEmpty ? DecorationImage(image: StorageNetworkImage(leitura.foto!), fit: BoxFit.cover) : null,
              ),
              child: leitura.foto == null || leitura.foto!.isEmpty ? const Icon(Icons.image_outlined, color: Colors.grey, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: leitura.etapa.cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text(leitura.etapa.label, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: leitura.etapa.cor)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Força: ${leitura.forcaKn.toStringAsFixed(1)} kN · Desloc.: ${leitura.deslocamentoMm.toStringAsFixed(2)}mm',
                    style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)),
                  ),
                  if (leitura.ocorrencia.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(leitura.ocorrencia, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
