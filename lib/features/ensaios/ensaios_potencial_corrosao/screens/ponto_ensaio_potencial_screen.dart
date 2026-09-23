import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';

import '../models/ponto_potencial_model.dart';
import '../repositories/potencial_repository.dart';
import 'analise_ponto_potencial_screen.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../../../../core/web/escolher_foto.dart';

class PontoEnsaioPotencialScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoEnsaioPotencialScreen({
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
  ConsumerState<PontoEnsaioPotencialScreen> createState() => _PontoEnsaioPotencialScreenState();
}

class _PontoEnsaioPotencialScreenState extends ConsumerState<PontoEnsaioPotencialScreen> {
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;
  bool _isEditingName = false;

  late TextEditingController _nomeCtrl;
  final TextEditingController _saturacaoCtrl = TextEditingController();
  final TextEditingController _temperaturaCtrl = TextEditingController();
  
  final TextEditingController _linhasCtrl = TextEditingController(text: '3');
  final TextEditingController _colunasCtrl = TextEditingController(text: '3');
  final TextEditingController _espacamentoXCtrl = TextEditingController(text: '10');
  final TextEditingController _espacamentoYCtrl = TextEditingController(text: '10');

  String _eletrodoSelecionado = 'Sulfato de Cobre';
  final List<String> _opcoesEletrodo = ['Sulfato de Cobre', 'Prata / Cloreto de Prata', 'Eletrodo de Calomelano'];

  File? _fotoElementoLocal, _fotoEnsaioLocal, _fotoBaseMapaLocal;
  String? _urlFotoElemento, _urlFotoEnsaio, _urlFotoBaseMapa;

  String? _pontoGeralIdAtual;
  String? _potencialIdAtual;

  List<List<PontoPotencialLeituraModel>> _malha = [];

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.pontoNome);
    
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
    _saturacaoCtrl.dispose();
    _temperaturaCtrl.dispose();
    _linhasCtrl.dispose();
    _colunasCtrl.dispose();
    _espacamentoXCtrl.dispose();
    _espacamentoYCtrl.dispose();
    super.dispose();
  }

  void _adicionarListeners() {
    _nomeCtrl.addListener(_onFieldChanged);
    _saturacaoCtrl.addListener(_onFieldChanged);
    _temperaturaCtrl.addListener(_onFieldChanged);
    _linhasCtrl.addListener(_recriarMalhaSeAlterada);
    _colunasCtrl.addListener(_recriarMalhaSeAlterada);
    _espacamentoXCtrl.addListener(_onFieldChanged);
    _espacamentoYCtrl.addListener(_onFieldChanged);
  }

  void _removerListeners() {
    _nomeCtrl.removeListener(_onFieldChanged);
    _saturacaoCtrl.removeListener(_onFieldChanged);
    _temperaturaCtrl.removeListener(_onFieldChanged);
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

    List<List<PontoPotencialLeituraModel>> novaMalha = List.generate(l, (i) => List.generate(c, (j) => PontoPotencialLeituraModel(linha: i, coluna: j)));

    for (int i = 0; i < min(l, _malha.length); i++) {
      for (int j = 0; j < min(c, _malha[i].length); j++) {
        novaMalha[i][j] = _malha[i][j];
      }
    }

    setState(() => _malha = novaMalha);
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(potencialRepositoryProvider);

      if (_pontoGeralIdAtual != null && _pontoGeralIdAtual!.isNotEmpty) {
        final dados = await repo.buscarPontoPotencial(_pontoGeralIdAtual!);
        if (dados != null) {
          _potencialIdAtual = dados.id;
          
          _urlFotoElemento = dados.imagemElemento;
          _urlFotoEnsaio = dados.imagemEnsaio;
          //_urlFotoBaseMapa = dados.imagemElementoEnsaio;
          
          _removerListeners();
          if (dados.eletrodo != null && _opcoesEletrodo.contains(dados.eletrodo)) {
            _eletrodoSelecionado = dados.eletrodo!;
          }
          _saturacaoCtrl.text = dados.tempoSaturacao ?? '';
          _temperaturaCtrl.text = dados.temperatura ?? '';
          _espacamentoXCtrl.text = dados.espacamentoX ?? '';
          _espacamentoYCtrl.text = dados.espacamentoY ?? '';

          int maxLinha = 0, maxColuna = 0;
          for (var l in dados.leituras) {
            if (l.linha > maxLinha) maxLinha = l.linha;
            if (l.coluna > maxColuna) maxColuna = l.coluna;
          }
          
          if (dados.leituras.isNotEmpty) {
            _linhasCtrl.text = (maxLinha + 1).toString();
            _colunasCtrl.text = (maxColuna + 1).toString();
            
            _malha = List.generate(maxLinha + 1, (i) => List.generate(maxColuna + 1, (j) => PontoPotencialLeituraModel(linha: i, coluna: j)));
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
            _fotoElementoLocal = File(file.path);
          } else if (tipo == 1) _fotoEnsaioLocal = File(file.path);
          //else _fotoBaseMapaLocal = File(file.path);
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
    // `pontos_ensaios_geral` e `ponto_ensaio_potencial` a partir de
    // `_pontoGeralIdAtual`/`_potencialIdAtual` (nulos pra um ponto novo), as
    // duas chamadas cairiam no ramo de INSERT e duplicariam as linhas.
    // Setar `_isLoading` aqui é síncrono (setState muda o campo na hora, só
    // o rebuild é adiado), então a segunda chamada já vê `_isLoading ==
    // true` e sai antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      List<PontoPotencialLeituraModel> leiturasParaSalvar = [];
      for (var linha in _malha) {
        leiturasParaSalvar.addAll(linha);
      }

      final model = PontoPotencialModel(
        id: _potencialIdAtual,
        pontoEnsaioId: _pontoGeralIdAtual,
        imagemElemento: _urlFotoElemento,
        imagemEnsaio: _urlFotoEnsaio,
        imagemElementoEnsaio: _urlFotoBaseMapa,
        eletrodo: _eletrodoSelecionado,
        tempoSaturacao: _saturacaoCtrl.text,
        temperatura: _temperaturaCtrl.text,
        espacamentoX: _espacamentoXCtrl.text,
        espacamentoY: _espacamentoYCtrl.text,
        leituras: leiturasParaSalvar,
      );

      final repo = ref.read(potencialRepositoryProvider);
      final res = await repo.salvarPotencialCompleto(
        dados: model,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        pontoNome: _nomeCtrl.text,
        fotoElementoLocal: _fotoElementoLocal,
        fotoEnsaioLocal: _fotoEnsaioLocal,
        fotoSobreposicaoLocal: _fotoBaseMapaLocal,
      );

      setState(() {
        _pontoGeralIdAtual = res['pontoGeralId'];
        _potencialIdAtual = res['potencialId'];
        if (res['urlElemento'] != null) _urlFotoElemento = res['urlElemento'];
        if (res['urlEnsaio'] != null) _urlFotoEnsaio = res['urlEnsaio'];
        if (res['urlSobreposicao'] != null) _urlFotoBaseMapa = res['urlSobreposicao'];
        _fotoElementoLocal = null;
        _fotoEnsaioLocal = null;
        _fotoBaseMapaLocal = null;
        _hasChanges = false; 
      });

      try { ref.invalidate(resumoEnsaiosProvider); } catch(_) {}

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalEdicaoCelula(int linha, int coluna) {
    final celulaAtual = _malha[linha][coluna];
    final ctrl = TextEditingController(text: celulaAtual.potencialMv != null ? celulaAtual.potencialMv!.toInt().toString() : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Leitura [${linha + 1}, ${coluna + 1}]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Valor em módulo (mV):', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(hintText: 'Ex: 350', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link, color: Colors.green),
              title: const Text('Linkar Resistividade', style: TextStyle(fontSize: 13)),
              trailing: Switch(
                value: celulaAtual.idLeituraResistividade != null, 
                onChanged: (val) {},
              ),
              onTap: () {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vínculo com resistividade em breve!'), duration: Duration(seconds: 1)));
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              setState(() {
                _malha[linha][coluna] = PontoPotencialLeituraModel(
                  id: celulaAtual.id,
                  pontoPotencialId: celulaAtual.pontoPotencialId,
                  linha: linha,
                  coluna: coluna,
                  potencialMv: val,
                  idLeituraResistividade: celulaAtual.idLeituraResistividade,
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

  Color _getBgColor(double? valor) {
    if (valor == null) return Colors.white;
    if (valor <= 200) return const Color(0xFFE8F5E9); 
    if (valor <= 350) return const Color(0xFFFFF3E0); 
    return const Color(0xFFFFEBEE); 
  }

  Color _getTextColor(double? valor) {
    if (valor == null) return Colors.grey.shade400;
    if (valor <= 200) return const Color(0xFF2E7D32);
    if (valor <= 350) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
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
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.info_outline, label: 'Informações', onTap: () {})),
          DiaviconMenuItem(
            icon: Icons.camera_alt_outlined, 
            label: 'Fotos', onTap: () {
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
            // AQUI: Os IDs necessários estão agora a ser passados para a tela de Análise
            Navigator.push(context, MaterialPageRoute(builder: (context) => AnalisePontoPotencialScreen(
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
            IconButton(iconSize: 30, color: Colors.red.shade800, icon: const Icon(Icons.delete_outline), onPressed: () { Navigator.pop(context); }),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Potencial de Corrosão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
      // AQUI: A SINTAXE FOI CORRIGIDA (SingleChildScrollView engloba o resto da UI)
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
              children: [
                Expanded(
                  child: _isEditingName
                      ? TextField(controller: _nomeCtrl, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold), onSubmitted: (_) => setState(() => _isEditingName = false))
                      : Text('${_nomeCtrl.text} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)))
                ),
                if (permissoes.canEdit)
                  IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square, color: const Color(0xFF3E3E3D)), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
              ],
            ),
            Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _buildCardFoto('Elemento Estrutural', _fotoElementoLocal, _urlFotoElemento, () => _capturarFoto(0))),
                const SizedBox(width: 12),
                Expanded(child: _buildCardFoto('Realizando Ensaio', _fotoEnsaioLocal, _urlFotoEnsaio, () => _capturarFoto(1))),
              ],
            ),
            const SizedBox(height: 16),
            

            Text('Preparação para o Ensaio', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 12),
            Text('Eletrodo Utilizado', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9E9E9E)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF9F9F9)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _eletrodoSelecionado,
                  items: _opcoesEletrodo.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) { if (val != null) setState(() { _eletrodoSelecionado = val; _hasChanges = true; }); },
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildInputGeral('Saturação (hr)', _saturacaoCtrl)),
                const SizedBox(width: 12),
                Expanded(child: _buildInputGeral('Temperatura (°C)', _temperaturaCtrl)),
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

            _buildSecaoGridPotencial(),

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

  Widget _buildSecaoGridPotencial() {
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Leituras nos pontos da malha', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFE3F2FD).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text('Escala calibrada para Cu/CuSO4 · valores em módulo', style: GoogleFonts.lato(fontSize: 11, color: Colors.blue.shade800))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('200', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            Expanded(
              child: Container(
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [Colors.green, Colors.orange, Colors.red]),
                ),
              ),
            ),
            Text('350+', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
                      final isPreenchido = cel.potencialMv != null;

                      return GestureDetector(
                        onTap: () => _abrirModalEdicaoCelula(l, c),
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _getBgColor(cel.potencialMv),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPreenchido ? _getTextColor(cel.potencialMv).withValues(alpha: 0.3) : Colors.grey.shade300,
                              style: isPreenchido ? BorderStyle.solid : BorderStyle.none,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!isPreenchido) Icon(Icons.add, color: Colors.grey.shade400, size: 18),
                              if (isPreenchido)
                                Text(cel.potencialMv!.toStringAsFixed(0), style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: _getTextColor(cel.potencialMv))),
                              if (isPreenchido && cel.idLeituraResistividade != null)
                                const Positioned(top: 2, right: 2, child: Icon(Icons.link, size: 10, color: Color(0xFF2E7D32))),
                            ],
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

  Widget _buildInputGeral(String label, TextEditingController ctrl, {bool isFullWidth = false}) {
    return Column(
      crossAxisAlignment: isFullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(controller: ctrl, textAlign: isFullWidth ? TextAlign.start : TextAlign.center, keyboardType: TextInputType.number, decoration: _inputDeco()),
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
        // Proporção fixa em vez de altura fixa: a foto não achata em tela larga.
        // Tocar continua capturando/trocando a foto.
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