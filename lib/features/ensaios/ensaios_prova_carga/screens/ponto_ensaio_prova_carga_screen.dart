import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/confirmar_exclusao_dialog.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/leitura_prova_carga_model.dart';
import '../models/ponto_medicao_model.dart';
import '../models/ponto_prova_carga_model.dart';
import '../providers/prova_carga_providers.dart';
import '../widgets/adicionar_medicao_modal.dart';
import '../widgets/croqui_prova_carga.dart';
import '../widgets/lista_pontos_medicao_modal.dart';
import '../widgets/selecionar_area_ensaio_modal.dart';
import 'analise_prova_carga_screen.dart';

/// Tela de coleta do ensaio de prova de carga estática.
class PontoEnsaioProvaCargaScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;

  const PontoEnsaioProvaCargaScreen({super.key, required this.pontoGeralId});

  @override
  ConsumerState<PontoEnsaioProvaCargaScreen> createState() => _PontoEnsaioProvaCargaScreenState();
}

class _PontoEnsaioProvaCargaScreenState extends ConsumerState<PontoEnsaioProvaCargaScreen> {
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isEditingName = false;
  String _etapaFiltro = 'Carregamento';
  final GlobalKey _croquiRepaintKey = GlobalKey();

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _cargaTotalCtrl;
  late final TextEditingController _carregamentoCtrl;
  late final TextEditingController _etapaCarregamentoCtrl;
  late final TextEditingController _etapaDescarregamentoCtrl;

  PontoProvaCargaModel? _area;
  List<PontoMedicaoModel> _pontosMedicao = [];
  List<LeituraProvaCargaModel> _leituras = [];
  String? _pontoSelecionadoNome;
  String? _localAtual;

  String? _estruturaId;
  String? _projetoId;
  String? _tipoEnsaioId;

  ImageProvider? _plantaImagem;
  bool _isLoadingPlanta = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController()..addListener(_onFieldChanged);
    _cargaTotalCtrl = TextEditingController(text: '0')..addListener(_onFieldChanged);
    _carregamentoCtrl = TextEditingController(text: '0')..addListener(_onFieldChanged);
    _etapaCarregamentoCtrl = TextEditingController(text: '0')..addListener(_onFieldChanged);
    _etapaDescarregamentoCtrl = TextEditingController(text: '0')..addListener(_onFieldChanged);
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cargaTotalCtrl.dispose();
    _carregamentoCtrl.dispose();
    _etapaCarregamentoCtrl.dispose();
    _etapaDescarregamentoCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_isInitializing && !_hasChanges) setState(() => _hasChanges = true);
  }

  Map<String, List<LeituraProvaCargaModel>> get _leiturasAgrupadas {
    final map = <String, List<LeituraProvaCargaModel>>{};
    for (final l in _leituras) {
      map.putIfAbsent(l.pontoMedicaoNome, () => []).add(l);
    }
    return map;
  }

  Map<String, bool> get _excedidoPorNome {
    final map = <String, bool>{};
    for (final ponto in _pontosMedicao) {
      final leituras = _leiturasAgrupadas[ponto.nome] ?? [];
      if (ponto.deslocMax == null || leituras.isEmpty) {
        map[ponto.nome] = false;
        continue;
      }
      final maxDesloc = leituras.map((l) => l.deslocamento).reduce((a, b) => a > b ? a : b);
      map[ponto.nome] = maxDesloc > ponto.deslocMax!;
    }
    return map;
  }

  void _verificarSelecao() {
    final nomes = _pontosMedicao.map((p) => p.nome).toList();
    if (nomes.isEmpty) {
      _pontoSelecionadoNome = null;
    } else if (_pontoSelecionadoNome == null || !nomes.contains(_pontoSelecionadoNome)) {
      _pontoSelecionadoNome = nomes.first;
    }
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(provaCargaRepositoryProvider);
      final dados = await repo.carregarPonto(widget.pontoGeralId);

      _nomeCtrl.text = dados['nomePonto'] ?? '';
      _estruturaId = dados['estruturaId'];
      _projetoId = dados['projetoId'];
      _tipoEnsaioId = dados['tipoEnsaioId'];
      _area = dados['area'] as PontoProvaCargaModel?;
      _pontosMedicao = List<PontoMedicaoModel>.from(dados['pontosMedicao']);
      _leituras = List<LeituraProvaCargaModel>.from(dados['leituras']);
      _verificarSelecao();

      _cargaTotalCtrl.text = (_area?.cargaTotal ?? 0).toString();
      _carregamentoCtrl.text = (_area?.carregamento ?? 0).toString();
      _etapaCarregamentoCtrl.text = (_area?.etapaCarregamento ?? 0).toString();
      _etapaDescarregamentoCtrl.text = (_area?.etapaDescarregamento ?? 0).toString();

      await _carregarPlantaImagem();

      final local = await repo.resolverLocalPeloElemento(_area?.elementoId);
      if (mounted) setState(() => _localAtual = local);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasChanges = false;
        });
      }
    }
  }

  Future<void> _carregarPlantaImagem() async {
    final url = _area?.plantaFoto;
    if (url == null || url.isEmpty) return;

    if (url.toLowerCase().contains('.pdf')) {
      setState(() => _isLoadingPlanta = true);
      try {
        final req = await HttpClient().getUrl(Uri.parse(await StorageUrls.assinar(url)));
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
        if (pageImg != null && mounted) setState(() => _plantaImagem = MemoryImage(pageImg.bytes));
        await page.close();
        await doc.close();
      } catch (e) {
        debugPrint('Erro PDF: $e');
      } finally {
        if (mounted) setState(() => _isLoadingPlanta = false);
      }
    } else {
      setState(() => _plantaImagem = StorageNetworkImage(url));
    }
  }

  Future<void> _editarArea() async {
    if (_area == null || _estruturaId == null || _projetoId == null || _tipoEnsaioId == null) return;

    final resultado = await showModalBottomSheet<PontoProvaCargaModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelecionarAreaEnsaioModal(
        estruturaId: _estruturaId!,
        projetoId: _projetoId!,
        tipoEnsaioId: _tipoEnsaioId!,
        nomeInicial: _nomeCtrl.text,
        plantaUrl: _area!.plantaFoto ?? '',
        areaExistente: _area,
      ),
    );

    if (resultado != null && mounted) {
      setState(() {
        _area = resultado;
        _hasChanges = true;
      });
    }
  }

  Future<void> _abrirListaPontos() async {
    final plantaUrl = _area?.plantaFoto;
    if (plantaUrl == null || plantaUrl.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ListaPontosMedicaoModal(
        plantaUrl: plantaUrl,
        pontosIniciais: _pontosMedicao,
        excedidoPorNome: _excedidoPorNome,
        onPontosChanged: (novos) {
          setState(() {
            _pontosMedicao = novos;
            _hasChanges = true;
            _verificarSelecao();
          });
        },
        onExcluirPontoPersistido: (id) async {
          final encontrados = _pontosMedicao.where((p) => p.id == id);
          final nomeRemovido = encontrados.isEmpty ? null : encontrados.first.nome;
          await ref.read(provaCargaRepositoryProvider).deletarPontoMedicao(id);
          if (nomeRemovido != null && mounted) {
            setState(() => _leituras.removeWhere((l) => l.pontoMedicaoNome == nomeRemovido));
          }
        },
      ),
    );
  }

  Future<void> _abrirModalMedicao({LeituraProvaCargaModel? leituraExistente}) async {
    if (_pontoSelecionadoNome == null) return;

    final resultado = await showAdicionarMedicaoModal(
      context,
      leituraExistente: leituraExistente,
      etapaPadrao: _etapaFiltro,
      pontoNome: _pontoSelecionadoNome!,
    );
    if (resultado == null) return;

    if (resultado.apagar) {
      if (leituraExistente != null) {
        if (leituraExistente.id != null) {
          setState(() => _isLoading = true);
          await ref.read(provaCargaRepositoryProvider).deletarLeitura(leituraExistente.id!);
        }
        setState(() {
          _leituras.remove(leituraExistente);
          _hasChanges = true;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      if (leituraExistente != null) {
        leituraExistente.deslocamento = resultado.deslocamento;
        leituraExistente.carregamento = resultado.carregamento;
        leituraExistente.etapa = resultado.etapa;
        leituraExistente.horario = resultado.horario;
      } else {
        _leituras.add(LeituraProvaCargaModel(
          pontoMedicaoNome: _pontoSelecionadoNome!,
          deslocamento: resultado.deslocamento,
          carregamento: resultado.carregamento,
          etapa: resultado.etapa,
          horario: resultado.horario,
        ));
      }
      _hasChanges = true;
    });
  }

  /// Captura o croqui (planta + área + pontos) já desenhado na tela, pra
  /// salvar como registro visual das marcações — ver Obs. 1 do usuário.
  Future<File?> _gerarImagemComposta() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _croquiRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/prova_carga_marcada_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      return file;
    } catch (e) {
      debugPrint('Erro ao capturar planta marcada: $e');
      return null;
    }
  }

  Future<void> _salvarDados() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarDados`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer,
    // disparando dois UPDATEs/INSERTs concorrentes em `pontos_ensaios_geral`
    // e `ponto_ensaio_prova_carga` (e suas leituras/pontos de medição
    // vinculados) pro mesmo ponto. Setar `_isLoading` aqui é síncrono
    // (setState muda o campo na hora, só o rebuild é adiado), então a
    // segunda chamada já vê `_isLoading == true` e sai antes de salvar de
    // novo.
    if (_isLoading) return;
    if (_area == null) return;
    setState(() => _isLoading = true);
    try {
      final areaAtualizada = _area!.copyWith(
        nome: _nomeCtrl.text.trim(),
        cargaTotal: int.tryParse(_cargaTotalCtrl.text.trim()) ?? 0,
        carregamento: int.tryParse(_carregamentoCtrl.text.trim()) ?? 0,
        etapaCarregamento: int.tryParse(_etapaCarregamentoCtrl.text.trim()) ?? 0,
        etapaDescarregamento: int.tryParse(_etapaDescarregamentoCtrl.text.trim()) ?? 0,
      );

      final excedidoMap = _excedidoPorNome;
      final algumExcedido = excedidoMap.values.any((v) => v);
      final temLeituras = _leituras.isNotEmpty;
      final valorResultado = algumExcedido ? 'Excedido' : (temLeituras ? 'OK' : 'Pendente');
      final corResultado = algumExcedido ? '#F44336' : (temLeituras ? '#4CAF50' : '#BDBDBD');

      await ref.read(provaCargaRepositoryProvider).salvarPonto(
            pontoGeralId: widget.pontoGeralId,
            nome: _nomeCtrl.text.trim(),
            area: areaAtualizada,
            pontosMedicao: _pontosMedicao,
            leituras: _leituras,
            valorResultado: valorResultado,
            corResultado: corResultado,
          );

      final imagemComposta = await _gerarImagemComposta();
      if (imagemComposta != null) {
        await ref.read(provaCargaRepositoryProvider).salvarImagemComposta(
              pontoGeralId: widget.pontoGeralId,
              imagem: imagemComposta,
            );
      }

      try {
        ref.invalidate(resumoEnsaiosProvider);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
      await _carregarDados();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletarPonto() async {
    final confirmar = await showConfirmarExclusaoDialog(
      context: context,
      mensagem: 'Deseja realmente excluir esta área de ensaio e todos os seus dados vinculados?',
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(provaCargaRepositoryProvider).deletarPontoCompleto(widget.pontoGeralId);
      try {
        ref.invalidate(resumoEnsaiosProvider);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));

    final leiturasDoSelecionado = _leiturasAgrupadas[_pontoSelecionadoNome] ?? [];
    final leiturasCarregamento = leiturasDoSelecionado.where((l) => l.etapa == 'Carregamento').toList()
      ..sort((a, b) => a.carregamento.compareTo(b.carregamento));
    final leiturasDescarregamento = leiturasDoSelecionado.where((l) => l.etapa == 'Descarregamento').toList()
      ..sort((a, b) => b.carregamento.compareTo(a.carregamento));
    final leiturasListaAtual = _etapaFiltro == 'Carregamento' ? leiturasCarregamento : leiturasDescarregamento;

    // No gráfico, o descarregamento deve visualmente partir de onde o
    // carregamento terminou (fisicamente é o mesmo ponto: a carga máxima
    // atingida), então o último ponto do carregamento é usado como ponto de
    // partida da curva de descarregamento.
    final dadosGraficoDescarregamento = [
      if (leiturasCarregamento.isNotEmpty) leiturasCarregamento.last,
      ...leiturasDescarregamento,
    ];

    final permissoes = ref.watch(ensaioPermissoesProvider(widget.pontoGeralId)).value ?? EnsaioPermissoes.somenteVisualizar;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Ponto de\nEnsaio',
        items: [
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(icon: Icons.info_outline, label: 'Informações', onTap: () {}),
          ),
          DiaviconMenuItem(
            icon: Icons.camera_alt_outlined,
            label: 'Fotos',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (_hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange),
                );
                return;
              }
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => GaleriaEnsaioScreen(
                    pontoGeralId: widget.pontoGeralId,
                    pontoNome: _nomeCtrl.text,
                    elementoNome: _area?.nome ?? _nomeCtrl.text,
                    tipoElemento: 'Prova de Carga Estática',
                    local: _localAtual ?? '-',
                    tipoEnsaio: _tipoEnsaioId ?? '',
                  ),
                ),
              );
            },
          ),
          DiaviconMenuItem(
            icon: Icons.show_chart_rounded,
            label: 'Análise',
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              if (_hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange),
                );
                return;
              }
              navigator.push(
                MaterialPageRoute(builder: (context) => AnaliseProvaCargaScreen(pontoGeralId: widget.pontoGeralId)),
              );
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
                _deletarPonto();
              },
            ),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Prova de Carga Estática', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _isEditingName
                      ? TextField(
                          controller: _nomeCtrl,
                          style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold),
                          onSubmitted: (_) => setState(() => _isEditingName = false),
                        )
                      : Text(_nomeCtrl.text, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (permissoes.canEdit)
                  IconButton(
                    icon: Icon(_isEditingName ? Icons.check : Icons.edit_square),
                    onPressed: () => setState(() => _isEditingName = !_isEditingName),
                  ),
              ],
            ),
            if (_localAtual != null) Text(_localAtual!, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            // --- CARGA E CARREGAMENTO ---
            Text('Carga e carregamento', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _campoNumero('Carga total (kg)', _cargaTotalCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _campoNumero('Carreg. (kg/m²)', _carregamentoCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Etapas', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _campoNumero('Carregamento', _etapaCarregamentoCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _campoNumero('Descarregamento', _etapaDescarregamentoCtrl)),
              ],
            ),
            const SizedBox(height: 24),

            // --- CROQUI ---
            Text('Croqui', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 12),
            _isLoadingPlanta
                ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : RepaintBoundary(
                    key: _croquiRepaintKey,
                    child: CroquiProvaCarga(
                      imagem: _plantaImagem,
                      area: _area,
                      pontos: _pontosMedicao,
                      excedidoPorNome: _excedidoPorNome,
                      pontoSelecionadoNome: _pontoSelecionadoNome,
                      onTapPonto: (ponto) => setState(() => _pontoSelecionadoNome = ponto.nome),
                    ),
                  ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _editarArea,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Área de Ensaio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _abrirListaPontos,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Ponto de Leitura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_pontosMedicao.isNotEmpty) ...[
              Text('Ponto de Medição', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _pontoSelecionadoNome,
                    items: _pontosMedicao.map((p) {
                      final excedeu = _excedidoPorNome[p.nome] ?? false;
                      return DropdownMenuItem(
                        value: p.nome,
                        child: Row(
                          children: [
                            Text(p.nome),
                            if (excedeu) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text('Excedido', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _pontoSelecionadoNome = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    title: AxisTitle(text: 'Carga (kg)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: 'Deslocamento (mm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    // Convenção de ensaios de carga: deslocamento cresce para
                    // baixo no gráfico (assentamento/recalque).
                    isInversed: true,
                  ),
                  legend: Legend(isVisible: true, position: LegendPosition.top),
                  series: [
                    LineSeries<LeituraProvaCargaModel, num>(
                      name: 'Carregamento',
                      dataSource: leiturasCarregamento,
                      xValueMapper: (l, _) => l.carregamento,
                      yValueMapper: (l, _) => l.deslocamento,
                      color: const Color(0xFFFFA726),
                      markerSettings: const MarkerSettings(isVisible: true),
                    ),
                    LineSeries<LeituraProvaCargaModel, num>(
                      name: 'Descarregamento',
                      dataSource: dadosGraficoDescarregamento,
                      xValueMapper: (l, _) => l.carregamento,
                      yValueMapper: (l, _) => l.deslocamento,
                      color: const Color(0xFF1B2A4A),
                      markerSettings: const MarkerSettings(isVisible: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _pillEtapa('Carregamento')),
                  const SizedBox(width: 12),
                  Expanded(child: _pillEtapa('Descarregamento')),
                ],
              ),
              const SizedBox(height: 12),

              if (leiturasListaAtual.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: Text('Nenhuma medição em $_etapaFiltro.', style: const TextStyle(color: Colors.grey))),
                )
              else
                ...leiturasListaAtual.map((l) => _cardLeitura(l)),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _abrirModalMedicao(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Adicionar medição', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Marque um Ponto de Leitura para começar a medir.', style: GoogleFonts.lato(color: Colors.grey)),
                ),
              ),

            const SizedBox(height: 48),
                ],
              ),
            ),

            if (_hasChanges && permissoes.canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _salvarDados,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                      : Text('Salvar Informações', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campoNumero(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            hintText: '000',
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _pillEtapa(String etapa) {
    final selecionado = _etapaFiltro == etapa;
    return GestureDetector(
      onTap: () => setState(() => _etapaFiltro = etapa),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionado ? AppColors.primary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          etapa,
          style: GoogleFonts.lato(color: selecionado ? Colors.white : const Color(0xFF686868), fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _cardLeitura(LeituraProvaCargaModel l) {
    final cor = l.etapa == 'Carregamento' ? const Color(0xFFFFA726) : const Color(0xFF1B2A4A);
    return GestureDetector(
      onTap: () => _abrirModalMedicao(leituraExistente: l),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deslocamento: ${l.deslocamento} mm', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF3E3E3D))),
                  Text('Hora: ${l.horario}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Text('${l.carregamento} kg', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: cor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(l.etapa, style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
