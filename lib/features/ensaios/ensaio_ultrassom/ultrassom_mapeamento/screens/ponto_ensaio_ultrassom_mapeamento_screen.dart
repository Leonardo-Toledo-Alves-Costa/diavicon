import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/custom_appbar.dart';
import '../../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../../core/widgets/diavicon_menu_item.dart';
import '../../../ensaios_geral/providers/ensaios_provider.dart';
import '../../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../models/ultrassom_mapeamento_model.dart';
import '../repositories/ultrassom_mapeamento_repository.dart';
import 'analise_ponto_ultrassom_mapeamento_screen.dart';
import '../../../../../core/web/escolher_foto.dart';

// Coleta do ensaio de Ultrassonografia — método Mapeamento. Mesmo padrão de
// `PontoEnsaioPotencialScreen` (malha de N x M pontos com espaçamento
// configurável, cada célula editável por toque) — a diferença é o campo
// medido (velocidade m/s em vez de potencial mV) e a classificação
// (Whitehurst, igual aos métodos Direto/Indireto de Ultrassonografia).
class PontoEnsaioUltrassomMapeamentoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;
  final String pulsoUltrassonico;

  const PontoEnsaioUltrassomMapeamentoScreen({
    super.key,
    required this.projetoId,
    required this.pontoNome,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.elementoId,
    this.pontoGeralId,
    required this.tipoEnsaioId,
    this.pulsoUltrassonico = 'Longitudinal',
  });

  @override
  ConsumerState<PontoEnsaioUltrassomMapeamentoScreen> createState() => _PontoEnsaioUltrassomMapeamentoScreenState();
}

class _PontoEnsaioUltrassomMapeamentoScreenState extends ConsumerState<PontoEnsaioUltrassomMapeamentoScreen> {
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;
  bool _isEditingName = false;

  late TextEditingController _nomeCtrl;

  final TextEditingController _linhasCtrl = TextEditingController(text: '3');
  final TextEditingController _colunasCtrl = TextEditingController(text: '3');
  final TextEditingController _espacamentoXCtrl = TextEditingController(text: '10');
  final TextEditingController _espacamentoYCtrl = TextEditingController(text: '10');

  late String _pulsoSelecionado;
  final List<String> _opcoesPulso = ['Longitudinal', 'Transversal'];

  File? _foto1Local, _foto2Local;
  String? _urlFoto1, _urlFoto2;

  String? _pontoGeralIdAtual;
  String? _idUltrassomAtual;
  String? _idMapeamentoAtual;

  // Coordenadas de calibração salvas pela tela de análise — preservadas ao
  // salvar aqui, pra não resetar a perspectiva já ajustada.
  String? _opacidadeSalva;
  double? _p1X, _p1Y, _p2X, _p2Y, _p3X, _p3Y, _p4X, _p4Y;

  List<List<LeituraUltrassomMapeamentoModel>> _malha = [];

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.pontoNome);
    _pulsoSelecionado = _opcoesPulso.contains(widget.pulsoUltrassonico) ? widget.pulsoUltrassonico : 'Longitudinal';

    if (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) {
      _pontoGeralIdAtual = widget.pontoGeralId;
    } else {
      _hasChanges = true;
    }

    _adicionarListeners();
    _carregarDados();
  }

  @override
  void dispose() {
    _removerListeners();
    _nomeCtrl.dispose();
    _linhasCtrl.dispose();
    _colunasCtrl.dispose();
    _espacamentoXCtrl.dispose();
    _espacamentoYCtrl.dispose();
    super.dispose();
  }

  void _adicionarListeners() {
    _nomeCtrl.addListener(_onFieldChanged);
    _linhasCtrl.addListener(_recriarMalhaSeAlterada);
    _colunasCtrl.addListener(_recriarMalhaSeAlterada);
    _espacamentoXCtrl.addListener(_onFieldChanged);
    _espacamentoYCtrl.addListener(_onFieldChanged);
  }

  void _removerListeners() {
    _nomeCtrl.removeListener(_onFieldChanged);
    _linhasCtrl.removeListener(_recriarMalhaSeAlterada);
    _colunasCtrl.removeListener(_recriarMalhaSeAlterada);
    _espacamentoXCtrl.removeListener(_onFieldChanged);
    _espacamentoYCtrl.removeListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _recriarMalhaSeAlterada() {
    _onFieldChanged();
    int l = int.tryParse(_linhasCtrl.text) ?? 3;
    int c = int.tryParse(_colunasCtrl.text) ?? 3;

    if (_malha.length == l && (_malha.isNotEmpty && _malha[0].length == c)) return;

    List<List<LeituraUltrassomMapeamentoModel>> novaMalha =
        List.generate(l, (i) => List.generate(c, (j) => LeituraUltrassomMapeamentoModel(linha: i, coluna: j)));

    for (int i = 0; i < min(l, _malha.length); i++) {
      for (int j = 0; j < min(c, _malha[i].length); j++) {
        novaMalha[i][j] = _malha[i][j];
      }
    }

    setState(() => _malha = novaMalha);
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(ultrassomMapeamentoRepositoryProvider);

      if (_pontoGeralIdAtual != null && _pontoGeralIdAtual!.isNotEmpty) {
        final dados = await repo.buscarPontoMapeamento(_pontoGeralIdAtual!);
        if (dados != null) {
          _idUltrassomAtual = dados.id;
          _idMapeamentoAtual = dados.mapeamentoId;
          _urlFoto1 = dados.foto1;
          _urlFoto2 = dados.foto2;

          _opacidadeSalva = dados.opacidade;
          _p1X = dados.p1X; _p1Y = dados.p1Y;
          _p2X = dados.p2X; _p2Y = dados.p2Y;
          _p3X = dados.p3X; _p3Y = dados.p3Y;
          _p4X = dados.p4X; _p4Y = dados.p4Y;

          _removerListeners();
          if (_opcoesPulso.contains(dados.pulsoUltrassonico)) _pulsoSelecionado = dados.pulsoUltrassonico;
          _espacamentoXCtrl.text = dados.espacamentoX ?? '10';
          _espacamentoYCtrl.text = dados.espacamentoY ?? '10';

          int maxLinha = 0, maxColuna = 0;
          for (var l in dados.leituras) {
            if (l.linha > maxLinha) maxLinha = l.linha;
            if (l.coluna > maxColuna) maxColuna = l.coluna;
          }

          if (dados.leituras.isNotEmpty) {
            _linhasCtrl.text = (maxLinha + 1).toString();
            _colunasCtrl.text = (maxColuna + 1).toString();

            _malha = List.generate(
                maxLinha + 1, (i) => List.generate(maxColuna + 1, (j) => LeituraUltrassomMapeamentoModel(linha: i, coluna: j)));
            for (var l in dados.leituras) {
              _malha[l.linha][l.coluna] = l;
            }
          } else {
            _recriarMalhaSeAlterada();
          }

          _adicionarListeners();
        }
      } else {
        _recriarMalhaSeAlterada();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _capturarFoto(int tipo) async {
    final picker = ImagePicker();
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

    if (source != null) {
      final file = await picker.pickImage(source: source, imageQuality: 80);
      if (file != null) {
        setState(() {
          if (tipo == 0) {
            _foto1Local = File(file.path);
          } else {
            _foto2Local = File(file.path);
          }
          _hasChanges = true;
        });
      }
    }
  }

  Future<void> _salvarDadosGerais() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarDadosGerais`) a partir do
    // PRÓXIMO rebuild/frame. Num toque duplo rápido, a segunda chamada ainda
    // acha o botão habilitado e entra aqui de novo antes do rebuild
    // acontecer. Como o repositório decide INSERT vs UPDATE em
    // `pontos_ensaios_geral`, `ponto_ensaio_ultrassom` e
    // `ponto_ensaio_ultrassom_mapeamento` a partir de
    // `_pontoGeralIdAtual`/`_idUltrassomAtual`/`_idMapeamentoAtual` (nulos
    // pra um ponto novo), as duas chamadas cairiam no ramo de INSERT e
    // duplicariam as linhas. Setar `_isLoading` aqui é síncrono (setState
    // muda o campo na hora, só o rebuild é adiado), então a segunda chamada
    // já vê `_isLoading == true` e sai antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      List<LeituraUltrassomMapeamentoModel> leiturasParaSalvar = [];
      for (var linha in _malha) {
        leiturasParaSalvar.addAll(linha);
      }

      final model = PontoUltrassomMapeamentoModel(
        id: _idUltrassomAtual,
        mapeamentoId: _idMapeamentoAtual,
        pontoGeralId: _pontoGeralIdAtual,
        pulsoUltrassonico: _pulsoSelecionado,
        foto1: _urlFoto1,
        foto2: _urlFoto2,
        espacamentoX: _espacamentoXCtrl.text,
        espacamentoY: _espacamentoYCtrl.text,
        opacidade: _opacidadeSalva,
        p1X: _p1X, p1Y: _p1Y, p2X: _p2X, p2Y: _p2Y, p3X: _p3X, p3Y: _p3Y, p4X: _p4X, p4Y: _p4Y,
        leituras: leiturasParaSalvar,
      );

      final repo = ref.read(ultrassomMapeamentoRepositoryProvider);
      final res = await repo.salvarMapeamentoCompleto(
        dados: model,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        pontoNome: _nomeCtrl.text,
        foto1Nova: _foto1Local,
        foto2Nova: _foto2Local,
      );

      setState(() {
        _pontoGeralIdAtual = res['pontoGeralId'];
        _idUltrassomAtual = res['idUltrassom'];
        _idMapeamentoAtual = res['idMapeamento'];
        if (res['urlFoto1'] != null) _urlFoto1 = res['urlFoto1'];
        if (res['urlFoto2'] != null) _urlFoto2 = res['urlFoto2'];
        _foto1Local = null;
        _foto2Local = null;
        _hasChanges = false;
      });

      try { ref.invalidate(resumoEnsaiosProvider); } catch (_) {}

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletarPonto() async {
    if (_pontoGeralIdAtual == null) {
      Navigator.pop(context);
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Ponto'),
        content: const Text('Deseja realmente excluir este ponto de ensaio e todos os seus dados vinculados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(ultrassomMapeamentoRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalEdicaoCelula(int linha, int coluna) {
    final celulaAtual = _malha[linha][coluna];
    final ctrl = TextEditingController(text: celulaAtual.velocidade != null ? celulaAtual.velocidade!.toInt().toString() : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leitura [${linha + 1}, ${coluna + 1}]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Velocidade (m/s):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: 'Ex: 3800', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              setState(() {
                _malha[linha][coluna] = LeituraUltrassomMapeamentoModel(
                  id: celulaAtual.id,
                  idMapeamento: celulaAtual.idMapeamento,
                  linha: linha,
                  coluna: coluna,
                  velocidade: val,
                );
                _hasChanges = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator()));

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralIdAtual ?? '')).value ?? EnsaioPermissoes.somenteVisualizar;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Ponto de\nEnsaio',
        items: [
          DiaviconMenuItem(
            icon: Icons.camera_alt_outlined,
            label: 'Fotos',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (_pontoGeralIdAtual == null || _hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange));
                return;
              }
              navigator.push(MaterialPageRoute(builder: (context) => GaleriaEnsaioScreen(
                  pontoGeralId: _pontoGeralIdAtual!,
                  pontoNome: widget.pontoNome,
                  elementoNome: widget.elementoNome,
                  tipoElemento: widget.tipoElemento,
                  local: widget.local,
                  tipoEnsaio: widget.tipoEnsaioId,
                )));
            },
          ),
          DiaviconMenuItem(icon: Icons.map_outlined, label: 'Análise de Mapa', onTap: () {
            Navigator.pop(context);
            if (_pontoGeralIdAtual == null || _hasChanges) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve o ponto primeiro para visualizar a análise.'), backgroundColor: Colors.orange));
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (context) => AnalisePontoUltrassomMapeamentoScreen(
                pontoGeralId: _pontoGeralIdAtual!,
                pontoNome: widget.pontoNome,
                elementoNome: widget.elementoNome,
                local: widget.local,
                projetoId: widget.projetoId,
                elementoId: widget.elementoId,
                tipoEnsaioId: widget.tipoEnsaioId,
              )));
          }),
          const Spacer(),
          const Divider(),
          if (permissoes.canDelete)
            IconButton(iconSize: 30, color: Colors.red.shade800, icon: const Icon(Icons.delete_outline), onPressed: () {
              Navigator.pop(context);
              _deletarPonto();
            }),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Ultrassonografia - Mapeamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
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
                    Expanded(
                      child: Text(
                        'Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _isEditingName
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(controller: _nomeCtrl, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold), onSubmitted: (_) => setState(() => _isEditingName = false)),
                                  const SizedBox(height: 8),
                                  _buildPulsoDropdownInline(),
                                ],
                              )
                            : Text('${_nomeCtrl.text} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))
                      ),
                      if (permissoes.canEdit)
                        IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square, color: const Color(0xFF3E3E3D)), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
                    ],
                  ),
                  Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                  Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                  if (!_isEditingName) Text('Pulso ${_pulsoSelecionado.toLowerCase()}', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: _buildCardFoto('Marcação da área', _foto1Local, _urlFoto1, () => _capturarFoto(0))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCardFoto('Realização do Ensaio', _foto2Local, _urlFoto2, () => _capturarFoto(1))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text('Execução do Ensaio', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            children: [
                              Text('Malha de pontos', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 45, height: 40, child: TextField(controller: _linhasCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: _inputDeco())),
                                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('x', style: TextStyle(color: Colors.grey))),
                                  SizedBox(width: 45, height: 40, child: TextField(controller: _colunasCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: _inputDeco())),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                          child: Column(
                            children: [
                              Text('Espaçamento (cm)', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 45, height: 40, child: TextField(controller: _espacamentoXCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: _inputDeco())),
                                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('x', style: TextStyle(color: Colors.grey))),
                                  SizedBox(width: 45, height: 40, child: TextField(controller: _espacamentoYCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, decoration: _inputDeco())),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _buildSecaoGridMapeamento(),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            if (_hasChanges && permissoes.canEdit)
              ElevatedButton(
                onPressed: _isLoading ? null : _salvarDadosGerais,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA726),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Salvar Informações', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoGridMapeamento() {
    int linhas = int.tryParse(_linhasCtrl.text) ?? 3;
    int colunas = int.tryParse(_colunasCtrl.text) ?? 3;
    int espX = int.tryParse(_espacamentoXCtrl.text) ?? 10;
    int espY = int.tryParse(_espacamentoYCtrl.text) ?? 10;

    if (_malha.isEmpty || _malha.length != linhas || _malha[0].length != colunas) {
      return const Center(child: Text('Ajuste as dimensões para ver a malha.', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leituras nos pontos da malha', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFE3F2FD).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Escala calibrada pela classificação Whitehurst · valores em m/s', style: GoogleFonts.lato(fontSize: 11, color: Colors.blue.shade800))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1500', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.lightGreen, Colors.green]),
                ),
              ),
            ),
            Text('5000+', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 24),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(65.0),
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  ...List.generate(colunas, (c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(((c + 1) * espX).toString(), textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    );
                  }),
                ],
              ),
              ...List.generate(linhas, (l) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 14.0),
                      child: Text((l * espY).toString(), textAlign: TextAlign.right, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                    ...List.generate(colunas, (c) {
                      final cel = _malha[l][c];
                      final isPreenchido = cel.velocidade != null;
                      final classificacao = isPreenchido ? ClassificacaoWhitehurst.classificar(cel.velocidade!) : null;

                      return GestureDetector(
                        onTap: () => _abrirModalEdicaoCelula(l, c),
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: classificacao?.cor.withValues(alpha: 0.12) ?? Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPreenchido ? classificacao!.cor.withValues(alpha: 0.4) : Colors.grey.shade300,
                              style: isPreenchido ? BorderStyle.solid : BorderStyle.none,
                            ),
                          ),
                          child: Center(
                            child: isPreenchido
                                ? Text(cel.velocidade!.toStringAsFixed(0), style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: classificacao!.cor))
                                : Icon(Icons.add, color: Colors.grey.shade400, size: 18),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPulsoDropdownInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Pulso: ', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
        DropdownButton<String>(
          value: _pulsoSelecionado,
          isDense: true,
          style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)),
          items: _opcoesPulso.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) { if (val != null) setState(() { _pulsoSelecionado = val; _hasChanges = true; }); },
        ),
      ],
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF9F9F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF9E9E9E), width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF9E9E9E), width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
          vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 30)),
          acao: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_square, size: 16, color: Color(0xFF3E3E3D)),
          ),
        ),
      ],
    );
  }
}
