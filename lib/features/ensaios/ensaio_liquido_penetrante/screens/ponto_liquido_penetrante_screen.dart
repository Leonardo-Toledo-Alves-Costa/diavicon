import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/liquido_penetrante_model.dart';
import '../repositories/liquido_penetrante_repository.dart';
import '../widgets/lp_widgets.dart';
import '../../../../core/web/escolher_foto.dart';

/// Ensaio de Líquido penetrante em um elemento metálico: lista dos pontos de
/// LP já registrados (cordões/juntas) + formulário de novo ponto na mesma
/// tela. O resultado do elemento é a contagem por status dos pontos.
class PontoLiquidoPenetranteScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoLiquidoPenetranteScreen({
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
  ConsumerState<PontoLiquidoPenetranteScreen> createState() => _PontoLiquidoPenetranteScreenState();
}

class _PontoLiquidoPenetranteScreenState extends ConsumerState<PontoLiquidoPenetranteScreen> {
  bool _carregando = true;
  bool _salvando = false;
  String? _pontoGeralId;
  List<PontoLiquidoPenetranteModel> _pontos = [];

  // Formulário (novo ponto, ou edição de um existente).
  final _nomeCtrl = TextEditingController();
  final _tamanhoCtrl = TextEditingController();
  final _tempoCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  StatusLP? _status;
  PontoLiquidoPenetranteModel? _editando;
  File? _fotoSolda, _fotoPenetrante, _fotoResultado;

  final _scrollCtrl = ScrollController();
  final _chaveFormulario = GlobalKey();

  @override
  void initState() {
    super.initState();
    final id = widget.pontoGeralId;
    _pontoGeralId = (id != null && id.isNotEmpty) ? id : null;
    _carregar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _tamanhoCtrl.dispose();
    _tempoCtrl.dispose();
    _descricaoCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  LiquidoPenetranteRepository get _repo => ref.read(liquidoPenetranteRepositoryProvider);

  Future<void> _carregar() async {
    if (_pontoGeralId == null) {
      setState(() => _carregando = false);
      return;
    }
    try {
      final pontos = await _repo.listarPontos(_pontoGeralId!);
      if (mounted) setState(() => _pontos = pontos);
    } catch (e) {
      _aviso(e.toString().replaceAll('Exception: ', ''), erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _aviso(String texto, {bool erro = false, bool alerta = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: erro ? Colors.red : (alerta ? Colors.orange : Colors.green),
    ));
  }

  void _limparFormulario() {
    _editando = null;
    _nomeCtrl.clear();
    _tamanhoCtrl.clear();
    _tempoCtrl.clear();
    _descricaoCtrl.clear();
    _status = null;
    _fotoSolda = _fotoPenetrante = _fotoResultado = null;
  }

  void _editar(PontoLiquidoPenetranteModel p) {
    setState(() {
      _limparFormulario();
      _editando = p;
      _nomeCtrl.text = p.nomePonto;
      _tamanhoCtrl.text = p.tamanhoAnalise;
      _tempoCtrl.text = p.tempoPenetracao;
      _descricaoCtrl.text = p.descricao;
      _status = p.status;
    });
    // Leva o formulário à vista.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _chaveFormulario.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
    });
  }

  Future<File?> _escolherFoto() async {
    final origem = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Câmera'), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeria'), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
          ],
        ),
      ),
    );
    if (origem == null) return null;
    final img = await ImagePicker().pickImage(source: origem, imageQuality: 85);
    return img == null ? null : File(img.path);
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (_nomeCtrl.text.trim().isEmpty) {
      _aviso('Informe a identificação do cordão / junta.', alerta: true);
      return;
    }
    if (_status == null) {
      _aviso('Escolha o status deste ponto.', alerta: true);
      return;
    }

    setState(() => _salvando = true);
    try {
      final ponto = PontoLiquidoPenetranteModel(
        id: _editando?.id,
        nomePonto: _nomeCtrl.text,
        fotoSolda: _editando?.fotoSolda,
        fotoPenetrante: _editando?.fotoPenetrante,
        fotoResultado: _editando?.fotoResultado,
        tamanhoAnalise: _tamanhoCtrl.text,
        tempoPenetracao: _tempoCtrl.text,
        descricao: _descricaoCtrl.text,
        status: _status,
      );
      _pontoGeralId = await _repo.salvarPonto(
        ponto: ponto,
        pontoGeralId: _pontoGeralId,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        nomeEnsaio: widget.pontoNome,
        fotoSoldaNova: _fotoSolda,
        fotoPenetranteNova: _fotoPenetrante,
        fotoResultadoNova: _fotoResultado,
      );
      final eraEdicao = _editando != null;
      _limparFormulario();
      ref.invalidate(resumoEnsaiosProvider);
      await _carregar();
      _aviso(eraEdicao ? 'Ponto atualizado!' : 'Ponto de LP salvo!');
    } catch (e) {
      _aviso(e.toString().replaceAll('Exception: ', ''), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirPonto(PontoLiquidoPenetranteModel p) async {
    if (p.id == null || _pontoGeralId == null) return;
    final ok = await _confirmar('Excluir ponto', 'Excluir o ponto "${p.nomePonto}"?');
    if (ok != true) return;
    setState(() => _salvando = true);
    try {
      await _repo.excluirPonto(pontoId: p.id!, pontoGeralId: _pontoGeralId!);
      if (_editando?.id == p.id) _limparFormulario();
      ref.invalidate(resumoEnsaiosProvider);
      await _carregar();
    } catch (e) {
      _aviso(e.toString().replaceAll('Exception: ', ''), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirEnsaio() async {
    if (_pontoGeralId == null) return;
    final ok = await _confirmar('Excluir ensaio', 'Excluir o ensaio de Líquido penetrante deste elemento e todos os seus pontos?');
    if (ok != true) return;
    try {
      await _repo.excluirEnsaioCompleto(_pontoGeralId!);
      ref.invalidate(resumoEnsaiosProvider);
      if (mounted) {
        _aviso('Ensaio excluído.');
        Navigator.pop(context);
      }
    } catch (e) {
      _aviso(e.toString().replaceAll('Exception: ', ''), erro: true);
    }
  }

  Future<bool?> _confirmar(String titulo, String texto) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(titulo),
          content: Text(texto),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralId ?? '')).value ??
        (_pontoGeralId == null ? EnsaioPermissoes.novo : EnsaioPermissoes.somenteVisualizar);
    final contagem = ContagemStatusLP.de(_pontos.map((p) => p.status));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _pontoGeralId == null
          ? null
          : MenuDrawerAppBar(
              title: 'Líquido\npenetrante',
              items: [
                DiaviconMenuItem(
                  icon: Icons.camera_alt_outlined,
                  label: 'Fotos',
                  onTap: () {
                    final navigator = Navigator.of(context)..pop();
                    navigator.push(MaterialPageRoute(
                      builder: (_) => GaleriaEnsaioScreen(
                        pontoGeralId: _pontoGeralId!,
                        pontoNome: widget.pontoNome,
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
                    tooltip: 'Excluir ensaio',
                    onPressed: () {
                      Navigator.pop(context);
                      _excluirEnsaio();
                    },
                  ),
              ],
            ),
      appBar: CustomAppBar(
        title: 'Líquido penetrante',
        showBackButton: true,
        showMenuButton: _pontoGeralId != null,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Líquido penetrante', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Elemento: ${widget.elementoNome}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (!permissoes.canEdit)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
            if (_pontos.isNotEmpty) ...[
              ResumoContagemLP(contagem: contagem, titulo: 'Resultado do elemento'),
              const SizedBox(height: 16),
            ],
            Text('Pontos de LP registrados', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            if (_pontos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Nenhum ponto registrado ainda.', style: GoogleFonts.lato(color: Colors.grey)),
              )
            else
              for (final p in _pontos) _cardPonto(p, permissoes),
            if (permissoes.canEdit) ...[
              const SizedBox(height: 16),
              _formulario(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cardPonto(PontoLiquidoPenetranteModel p, EnsaioPermissoes permissoes) {
    final selecionado = _editando?.id == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: permissoes.canEdit ? () => _editar(p) : null,
        onLongPress: permissoes.canDelete ? () => _excluirPonto(p) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selecionado ? AppColors.primary : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nomePonto.isEmpty ? 'Ponto sem nome' : p.nomePonto,
                        style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
                    const SizedBox(height: 2),
                    Text(p.resumo, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              BadgeStatusLP(p.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    final editando = _editando != null;
    return Container(
      key: _chaveFormulario,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEAF1FB), borderRadius: BorderRadius.circular(16)),
      child: AbsorbPointer(
        absorbing: _salvando,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(editando ? Icons.edit_outlined : Icons.add, size: 18, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(editando ? 'Editar ponto de LP' : 'Novo ponto de LP',
                      style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E3A5F))),
                ),
                if (editando)
                  TextButton(onPressed: () => setState(_limparFormulario), child: const Text('Cancelar edição')),
              ],
            ),
            const SizedBox(height: 10),
            _rotulo('Identificação do cordão / junta'),
            TextField(controller: _nomeCtrl, decoration: _deco('ex: Cordão C-04, junta viga-pilar')),
            const SizedBox(height: 14),
            _rotulo('Fotos deste ponto'),
            Row(
              children: [
                Expanded(child: _foto('Solda', _fotoSolda, _editando?.fotoSolda, (f) => _fotoSolda = f)),
                const SizedBox(width: 8),
                Expanded(child: _foto('Com penetrante', _fotoPenetrante, _editando?.fotoPenetrante, (f) => _fotoPenetrante = f)),
                const SizedBox(width: 8),
                Expanded(child: _foto('Resultado', _fotoResultado, _editando?.fotoResultado, (f) => _fotoResultado = f)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _campoNumero('Tamanho analisado', _tamanhoCtrl, 'cm')),
                const SizedBox(width: 12),
                Expanded(child: _campoNumero('Tempo de penetração', _tempoCtrl, 'min')),
              ],
            ),
            const SizedBox(height: 14),
            _rotulo('Descrição'),
            TextField(controller: _descricaoCtrl, maxLines: 3, decoration: _deco('Observações sobre este ponto')),
            const SizedBox(height: 14),
            _rotulo('Status deste ponto'),
            _seletorStatus(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _salvando ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _salvando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(editando ? 'Salvar alterações' : 'Salvar ponto',
                      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rotulo(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
      );

  Widget _campoNumero(String rotulo, TextEditingController ctrl, String unidade) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rotulo(rotulo),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _deco(''),
              ),
            ),
            const SizedBox(width: 6),
            Text(unidade, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
      ],
    );
  }

  Widget _foto(String titulo, File? local, String? url, void Function(File) definir) {
    ImageProvider? img;
    if (local != null) {
      img = ResizeImage(FileImage(local), width: 300);
    } else if (url != null && url.isNotEmpty) {
      img = ResizeImage(StorageNetworkImage(url), width: 300);
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final f = await _escolherFoto();
            if (f != null) setState(() => definir(f));
          },
          child: AspectRatio(
            aspectRatio: 0.9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
              ),
              child: img == null ? Icon(Icons.image_outlined, color: Colors.grey.shade500) : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(titulo, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _seletorStatus() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          for (final s in StatusLP.values)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _status = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _status == s ? s.fundo : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: _status == s ? Border.all(color: s.cor) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    s.label,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: _status == s ? FontWeight.w800 : FontWeight.w500,
                      color: _status == s ? s.cor : const Color(0xFF3E3E3D),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
