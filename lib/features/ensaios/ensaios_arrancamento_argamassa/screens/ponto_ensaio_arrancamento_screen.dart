import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import 'analise_ponto_arrancamento_screen.dart';

// Providers
import '../../ensaios_geral/providers/ensaios_provider.dart'; // <-- Ajuste o caminho se necessário para o seu resumoEnsaiosProvider

// Modelos e Repositórios locais
import '../models/ponto_arrancamento_model.dart';
import '../repositories/arrancamento_repository.dart';
import '../../ensaios_geral/widgets/info_tooltip_dialog.dart';
import '../widgets/modal_ponto_leitura_arrancamento.dart';

class PontoEnsaioArrancamentoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoEnsaioArrancamentoScreen({
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
  ConsumerState<PontoEnsaioArrancamentoScreen> createState() => _PontoEnsaioArrancamentoScreenState();
}

class _PontoEnsaioArrancamentoScreenState extends ConsumerState<PontoEnsaioArrancamentoScreen> {
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false; // <-- Controle do botão Salvar

  late TextEditingController _nomeCtrl;
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _umidCtrl = TextEditingController();
  final TextEditingController _idadeCtrl = TextEditingController();
  final TextEditingController _colaCtrl = TextEditingController();

  final List<String> _opcoesSubstrato = ['Bloco cerâmico', 'Bloco de concreto', 'Superfície de concreto'];
  String? _substratoSelecionado;

  File? _fotoRegiaoLocal;
  File? _fotoPastilhasLocal;
  String? _urlFotoRegiao;
  String? _urlFotoPastilhas;

  String? _pontoGeralIdAtual;
  String? _arrancamentoIdAtual;
  List<PontoArrancamentoLeituraModel> _leituras = [];

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.pontoNome);
    
    if (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) {
      _pontoGeralIdAtual = widget.pontoGeralId;
    } else {
      _hasChanges = true; // Se é um ponto novo, já precisa salvar
    }
    
    _substratoSelecionado = _opcoesSubstrato.first;
    _adicionarListeners();
    _carregarDados();
  }

  @override
  void dispose() {
    _removerListeners();
    _nomeCtrl.dispose();
    _tempCtrl.dispose();
    _umidCtrl.dispose();
    _idadeCtrl.dispose();
    _colaCtrl.dispose();
    super.dispose();
  }

  // --- CONTROLE DE EDIÇÕES (LISTENERS) ---
  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _adicionarListeners() {
    _nomeCtrl.addListener(_onFieldChanged);
    _tempCtrl.addListener(_onFieldChanged);
    _umidCtrl.addListener(_onFieldChanged);
    _idadeCtrl.addListener(_onFieldChanged);
    _colaCtrl.addListener(_onFieldChanged);
  }

  void _removerListeners() {
    _nomeCtrl.removeListener(_onFieldChanged);
    _tempCtrl.removeListener(_onFieldChanged);
    _umidCtrl.removeListener(_onFieldChanged);
    _idadeCtrl.removeListener(_onFieldChanged);
    _colaCtrl.removeListener(_onFieldChanged);
  }
  // ---------------------------------------

  // --- INCLUA ESTA FUNÇÃO NO STATE DA TELA ---
  // --- ADICIONE ESTA FUNÇÃO NO STATE ---
  Future<void> _deletarPonto() async {
    if (_pontoGeralIdAtual == null) {
      Navigator.pop(context);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Ponto'),
        content: const Text('Deseja realmente excluir este ponto de ensaio e todas as suas leituras vinculadas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(arrancamentoRepositoryProvider);
      await repo.deletarPontoCompleto(_pontoGeralIdAtual!, _arrancamentoIdAtual);

      if (mounted) {
        try { ref.invalidate(resumoEnsaiosProvider); } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Fecha a tela atual e volta pra lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(arrancamentoRepositoryProvider);

      if (_pontoGeralIdAtual != null && _pontoGeralIdAtual!.isNotEmpty) {
        final dados = await repo.buscarPontoArrancamento(_pontoGeralIdAtual!);
        if (dados != null) {
          _arrancamentoIdAtual = dados.id;
          _urlFotoRegiao = dados.imagemRegiao;
          _urlFotoPastilhas = dados.imagemColagem;
          
          // Desativa os listeners temporariamente para não acionar o _hasChanges durante a carga
          _removerListeners();
          _tempCtrl.text = dados.temperatura ?? '';
          _umidCtrl.text = dados.umidade ?? '';
          _idadeCtrl.text = dados.idadeRevestimento ?? '';
          _colaCtrl.text = dados.colaUtilizada ?? '';
          _adicionarListeners();

          if (dados.tipoSubstrato != null && dados.tipoSubstrato!.isNotEmpty) {
            if (!_opcoesSubstrato.contains(dados.tipoSubstrato)) {
              _opcoesSubstrato.add(dados.tipoSubstrato!);
            }
            _substratoSelecionado = dados.tipoSubstrato;
          }
          _leituras = List.from(dados.leituras);
        }
      }

      if (_idadeCtrl.text.isEmpty) {
        final idadeDefault = await repo.buscarIdadeEstruturaPorElemento(widget.elementoId);
        if (idadeDefault != null && mounted) {
          _removerListeners();
          _idadeCtrl.text = idadeDefault;
          _adicionarListeners();
          _hasChanges = true; // Sugeriu a idade? O usuário precisa salvar.
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  

  Future<void> _capturarFoto(bool isRegiao) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Tirar foto com a Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Escolher da Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final file = await picker.pickImage(source: source, imageQuality: 80);
      if (file != null) {
        setState(() {
          if (isRegiao) {
            _fotoRegiaoLocal = File(file.path);
          } else {
            _fotoPastilhasLocal = File(file.path);
          }
          _hasChanges = true; // Ativa o botão Salvar
        });
      }
    }
  }

  Future<void> _salvarGeral({bool mostrarFeedback = true}) async {
    setState(() => _isLoading = true);
    try {
      final model = PontoArrancamentoModel(
        id: _arrancamentoIdAtual,
        pontoEnsaioId: _pontoGeralIdAtual,
        imagemRegiao: _urlFotoRegiao,
        imagemColagem: _urlFotoPastilhas,
        norma: 'ABNT NBR 13525-2:2019',
        tipoSubstrato: _substratoSelecionado,
        temperatura: _tempCtrl.text,
        umidade: _umidCtrl.text,
        idadeRevestimento: _idadeCtrl.text,
        colaUtilizada: _colaCtrl.text,
        leituras: _leituras,
      );

      final repo = ref.read(arrancamentoRepositoryProvider);
      final res = await repo.salvarArrancamentoCompleto(
        dados: model,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        pontoNome: _nomeCtrl.text,
        fotoRegiao: _fotoRegiaoLocal,
        fotoColagem: _fotoPastilhasLocal,
      );

      setState(() {
        _pontoGeralIdAtual = res['pontoGeralId'];
        _arrancamentoIdAtual = res['arrancamentoId'];
        if (res['urlRegiao'] != null) _urlFotoRegiao = res['urlRegiao'];
        if (res['urlColagem'] != null) _urlFotoPastilhas = res['urlColagem'];
        _fotoRegiaoLocal = null;
        _fotoPastilhasLocal = null;
        _hasChanges = false; // <-- Esconde o botão após salvar com sucesso
      });

      // <-- INVALIDE O PROVIDER AQUI PARA RECARREGAR A TELA ANTERIOR -->
      // Caso sua tela de pontos geral use este provider específico (ajuste se usar outro nome):
      try {
        ref.invalidate(resumoEnsaiosProvider);
      } catch(_) {}

      if (mostrarFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informações salvas com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalAdicionarOuEditarSubstrato({String? valorAtual}) {
    final ctrl = TextEditingController(text: valorAtual ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(valorAtual == null ? 'Adicionar Substrato' : 'Editar Substrato'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Ex: Argamassa colante AC-III'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (valorAtual != null) {
                    final idx = _opcoesSubstrato.indexOf(valorAtual);
                    if (idx != -1) _opcoesSubstrato[idx] = text;
                  } else {
                    if (!_opcoesSubstrato.contains(text)) _opcoesSubstrato.add(text);
                  }
                  _substratoSelecionado = text;
                  _hasChanges = true; // Ativa o botão Salvar
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _abrirModalPontoLeitura({PontoArrancamentoLeituraModel? leituraExistente}) async {
    // Exige salvar a aba geral antes de cadastrar pontos secundários
    if (_arrancamentoIdAtual == null || _hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, salve as informações gerais do ensaio primeiro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final proximoNumero = _leituras.length + 1;
    final nomeSugerido = 'Ponto ${proximoNumero.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ModalPontoLeituraArrancamento(
        leituraExistente: leituraExistente,
        nomeSugerido: nomeSugerido,
        onSalvar: (leituraSalvar, fEnsaio, fRuptura) async {
          final repo = ref.read(arrancamentoRepositoryProvider);
          await repo.salvarPontoLeitura(
            idArrancamento: _arrancamentoIdAtual!,
            leitura: leituraSalvar,
            fotoEnsaio: fEnsaio,
            fotoRuptura: fRuptura,
          );
          
          // Invalida o provider geral quando finaliza uma leitura, para atualizar os contadores externos se necessário
          try { ref.invalidate(resumoEnsaiosProvider); } catch(_) {}
          
          await _carregarDados();
        },
        onApagar: leituraExistente?.id != null
            ? () async {
                final repo = ref.read(arrancamentoRepositoryProvider);
                await repo.deletarPontoLeitura(leituraExistente!.id!);
                if (mounted) Navigator.pop(context);
                await _carregarDados();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final modelAtual = PontoArrancamentoModel(leituras: _leituras);
    final totalPontos = _leituras.length;
    final bool atendeMinimo = totalPontos >= 12;

    return Scaffold(
      backgroundColor: Colors.white,

      endDrawer: MenuDrawerAppBar(
          title: 'Ponto de\nensaio',
          items: [
            Opacity(
              opacity: 0.4,
              child: DiaviconMenuItem(
                icon: Icons.info_outline,
                label: 'Informações',
                onTap: () {},
              ),
            ),
            DiaviconMenuItem(
              icon: Icons.camera_alt_outlined,
              label: 'Fotos',
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                if (_pontoGeralIdAtual == null || _hasChanges) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Salve as informações primeiro.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => GaleriaEnsaioScreen(
                      pontoGeralId: _pontoGeralIdAtual!,
                      pontoNome: _nomeCtrl.text,
                      elementoNome: widget.elementoNome,
                      tipoElemento: widget.tipoElemento,
                      local: widget.local,
                      tipoEnsaio: 'Arrancamento em Argamassa',
                    ),
                  ),
                );
              },
            ),

            DiaviconMenuItem(
              icon: Icons.show_chart_rounded,
              label: 'Análise',
              onTap: () {
                Navigator.pop(context);
                if (_pontoGeralIdAtual == null || _hasChanges) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Salve o ponto primeiro para visualizar a análise.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AnalisePontoArrancamentoScreen(
                          pontoGeralId: _pontoGeralIdAtual!,
                          pontoNome: _nomeCtrl.text,
                          elementoNome: widget.elementoNome,
                          local: widget.local,
                        ),
                  ),
                );
              },
            ),

            const Spacer(),
            const Divider(),

            Center(
              child: IconButton(
                iconSize: 30,
                color: Colors.red.shade800,
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  Navigator.pop(context);
                  _deletarPonto();
                },
              ),
            ),
          ],
        ),


      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text('Arrancamento em Argamassa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_nomeCtrl.text} - ${widget.elementoNome}',
                    style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
                  onPressed: () {},
                ),
              ],
            ),
            Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildCardFotoPrincipal(
                    titulo: 'Região de ensaio',
                    localFile: _fotoRegiaoLocal,
                    url: _urlFotoRegiao,
                    onTap: () => _capturarFoto(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCardFotoPrincipal(
                    titulo: 'Pastilhas coladas',
                    localFile: _fotoPastilhasLocal,
                    url: _urlFotoPastilhas,
                    onTap: () => _capturarFoto(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Dados gerais do ensaio', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 4),
            Text('Norma: ABNT NBR 13525-2:2019', style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF757575))),
            const SizedBox(height: 12),

            Text('Equipamento Utilizado', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: 'Dinamômetro de Tração Digital 5kN',
                  items: const [
                    DropdownMenuItem(value: 'Dinamômetro de Tração Digital 5kN', child: Text('Dinamômetro de Tração Digital 5kN')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text('Tipo Substrato', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _substratoSelecionado,
                        items: _opcoesSubstrato.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null && val != _substratoSelecionado) {
                            setState(() {
                              _substratoSelecionado = val;
                              _hasChanges = true;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AppColors.primary),
                  onPressed: () => _abrirModalAdicionarOuEditarSubstrato(valorAtual: _substratoSelecionado),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 24, color: AppColors.primary),
                  onPressed: () => _abrirModalAdicionarOuEditarSubstrato(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: _buildInputGeral('T (°C)', _tempCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _buildInputGeral('U (%)', _umidCtrl)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Idade (anos)', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () => InfoTooltipDialog.show(
                              context,
                              titulo: 'Idade do Revestimento',
                              texto: 'Idade aproximada do revestimento calculada com base no ano de concepção da estrutura.',
                            ),
                            child: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _idadeCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD9D9D9))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildInputGeral('Cola utilizada', _colaCtrl, isFullWidth: true),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pontos de Arrancamento', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: atendeMinimo ? const Color(0xFFE8F5E9) : const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalPontos realizados',
                    style: GoogleFonts.lato(
                      color: atendeMinimo ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: _leituras.isEmpty
                  ? Center(child: Text('Nenhum ponto registrado ainda.', style: GoogleFonts.lato(color: Colors.grey)))
                  : Column(
                      children: _leituras.map((leitura) {
                        return GestureDetector(
                          onTap: () => _abrirModalPontoLeitura(leituraExistente: leitura),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey.shade200,
                                    child: leitura.imagemEnsaio != null
                                        ? Image.network(leitura.imagemEnsaio!, fit: BoxFit.cover)
                                        : const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(leitura.nome, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('Tensão Máx: ${leitura.tensaoCalculada.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
                                      Text('Ruptura: ${leitura.resumoRupturas}', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Média', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                        Text('${modelAtual.mediaTensao.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coef. de variação', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                        Row(
                          children: [
                            Text('${modelAtual.coefVariacao.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: modelAtual.coefVariacao <= 20 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                modelAtual.coefVariacao <= 20 ? 'Homogêneo' : 'Heterogêneo',
                                style: TextStyle(fontSize: 8, color: modelAtual.coefVariacao <= 20 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _abrirModalPontoLeitura(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Color(0xFFFFA726), shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // O BOTÃO DE SALVAR SÓ APARECE SE HOUVER ALTERAÇÕES PENDENTES
            if (_hasChanges)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _salvarGeral(mostrarFeedback: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Salvar Informações', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGeral(String label, TextEditingController ctrl, {bool isFullWidth = false}) {
    return Column(
      crossAxisAlignment: isFullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          textAlign: isFullWidth ? TextAlign.start : TextAlign.center,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD9D9D9))),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFotoPrincipal({
    required String titulo,
    File? localFile,
    String? url,
    required VoidCallback onTap,
  }) {
    ImageProvider? img;
    if (localFile != null) {
      img = FileImage(localFile);
    } else if (url != null && url.isNotEmpty) {
      img = NetworkImage(url);
    }

    return Column(
      children: [
        Text(titulo, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: img != null ? DecorationImage(image: img, fit: BoxFit.cover) : null,
                ),
                child: img == null ? const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 32) : null,
              ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.edit_square, size: 18, color: Color(0xFF3E3E3D)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}