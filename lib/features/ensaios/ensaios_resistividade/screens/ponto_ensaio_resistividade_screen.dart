import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';

import '../models/ponto_resistividade_model.dart';
import '../repositories/resistividade_repository.dart';

import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import 'analise_pontos_resistividade.dart';
import '../utils/classificacao_resistividade.dart';
import '../../../../core/web/escolher_foto.dart';

class PontoEnsaioResistividadeScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoEnsaioResistividadeScreen({
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
  ConsumerState<PontoEnsaioResistividadeScreen> createState() => _PontoEnsaioResistividadeScreenState();
}

class _PontoEnsaioResistividadeScreenState extends ConsumerState<PontoEnsaioResistividadeScreen> {
  final GlobalKey _gridRepaintKey = GlobalKey();

  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;

  late TextEditingController _nomePontoCtrl;

  List<PontoResistividadeLeituraModel> _leituras = [];
  String? _pontoSelecionadoUI; 
  
  File? _fotoElementoLocal;
  File? _fotoRealizandoLocal;
  File? _fotoGridLocal;

  String? _urlFotoElemento;
  String? _urlFotoRealizando;
  String? _urlFotoGrid;

  String? _pontoGeralIdAtual;

  @override
  void initState() {
    super.initState();
    _nomePontoCtrl = TextEditingController(text: widget.pontoNome);
    
    if (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) {
      _pontoGeralIdAtual = widget.pontoGeralId;
    } else {
      _hasChanges = true;
    }

    _nomePontoCtrl.addListener(_onFieldChanged);
    _carregarDadosExistentes();
  }

  @override
  void dispose() {
    _nomePontoCtrl.removeListener(_onFieldChanged);
    _nomePontoCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  // --- Lógicas de Agrupamento ---
  Map<String, List<PontoResistividadeLeituraModel>> get _leiturasAgrupadas {
    final map = <String, List<PontoResistividadeLeituraModel>>{};
    for (var l in _leituras) {
      final nome = l.nomeLeitura ?? 'Ponto 1';
      map.putIfAbsent(nome, () => []).add(l);
    }
    return map;
  }

  List<String> get _nomesPontos {
    final nomes = _leiturasAgrupadas.keys.toList();
    nomes.sort((a, b) => a.compareTo(b));
    return nomes;
  }

  void _verificarSelecaoUI() {
    final nomes = _nomesPontos;
    if (nomes.isNotEmpty) {
      if (_pontoSelecionadoUI == null || !nomes.contains(_pontoSelecionadoUI)) {
        _pontoSelecionadoUI = nomes.first;
      }
    } else {
      _pontoSelecionadoUI = null;
    }
  }

  // --- Risco de corrosao: fonte unica (ClassificacaoResistividade). ---
  // A copia antiga devolvia o mesmo hex laranja pra quase todas as classes,
  // entao o marcador no mapa nao mudava de cor com o risco.
  Map<String, dynamic> _avaliarRisco(double media) {
    final classe = ClassificacaoResistividade.risco.classificar(media);
    if (classe == null) return {'texto': 'Pendente', 'cor': Colors.grey.shade500, 'hex': '#BDBDBD'};
    final argb = classe.corTexto.toARGB32();
    final hex = '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    return {'texto': classe.texto, 'cor': classe.corTexto, 'hex': hex};
  }

  // --- Helpers de Tempo para o Gráfico ---
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    // Prevenção contra strings vazias ou mal formatadas
    if (parts.length < 2) return DateTime(2000, 1, 1);
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(2000, 1, 1, h, m);
  }

  int _getDeltaMinutes(String horaAtual, String horaInicial) {
    final tAtual = _parseTime(horaAtual);
    final tIni = _parseTime(horaInicial);
    final diff = tAtual.difference(tIni);
    if (diff.isNegative) return 0; 
    return diff.inMinutes;
  }

  // --- Banco de Dados ---
  Future<void> _carregarDadosExistentes() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      
      final geralResp = await supabase.from('pontos_ensaios_geral').select('*').eq('id', _pontoGeralIdAtual!).maybeSingle();
      if (geralResp != null) _nomePontoCtrl.text = geralResp['nome_ponto'] ?? widget.pontoNome;

      final leiturasResp = await supabase.from('ponto_ensaio_resistividade_leitura').select('*').eq('id_ponto_geral', _pontoGeralIdAtual!).order('criado_em', ascending: true);
      
      _leituras = (leiturasResp as List).map((l) {
        // Intercepta e corrige o problema do 00:00:00 do banco
        final Map<String, dynamic> mutableL = Map.from(l);
        if (mutableL['hora'] != null && mutableL['hora'].toString().length >= 5) {
          mutableL['hora'] = mutableL['hora'].toString().substring(0, 5); // Corta os segundos
        }
        return PontoResistividadeLeituraModel.fromJson(mutableL);
      }).toList();
      
      _verificarSelecaoUI();

      final fotosResp = await supabase.from('galeria_ponto_ensaio_resistividade').select('imagem_url, referencia').eq('ponto_ensaio_id', _pontoGeralIdAtual!);
      for (var foto in (fotosResp as List)) {
        if (foto['referencia'] == '1') _urlFotoElemento = foto['imagem_url'];
        if (foto['referencia'] == '2') _urlFotoRealizando = foto['imagem_url'];
        if (foto['referencia'] == '3') _urlFotoGrid = foto['imagem_url'];
      }
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro DB: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasChanges = false; 
        });
      }
    }
  }

  Future<void> _capturarFoto(int referencia) async {
    final ImageSource? source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
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
      final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          if (referencia == 1) _fotoElementoLocal = File(image.path);
          if (referencia == 2) _fotoRealizandoLocal = File(image.path);
          if (referencia == 3) _fotoGridLocal = File(image.path);
          _hasChanges = true; 
        });
      }
    }
  }

  Future<File?> _gerarImagemGridComPontos() async {
    try {
      RenderRepaintBoundary? boundary = _gridRepaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final buffer = byteData.buffer;
        final tempDir = Directory.systemTemp;
        File file = File('${tempDir.path}/grid_pontos_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        return file;
      }
    } catch (e) {
      debugPrint('Erro ao capturar RepaintBoundary: $e');
    }
    return null;
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
      await ref.read(resistividadeRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);

      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Modais de Leitura ---
  void _abrirModalLeitura({int? indexAtualizar, double? posX, double? posY, String? nomePontoParaAdicionar}) {
    final resCtrl = TextEditingController(text: indexAtualizar != null ? _leituras[indexAtualizar].resistividade.toString() : '');
    final horaCtrl = TextEditingController(text: indexAtualizar != null ? _leituras[indexAtualizar].hora : '');
    final tempCtrl = TextEditingController(text: indexAtualizar != null ? _leituras[indexAtualizar].temperatura.toString() : '25'); 

    if (nomePontoParaAdicionar != null && _leiturasAgrupadas.containsKey(nomePontoParaAdicionar)) {
      final ref = _leiturasAgrupadas[nomePontoParaAdicionar]!.first;
      posX = ref.posX;
      posY = ref.posY;
    }

    final novoNomeDefault = nomePontoParaAdicionar ?? 'Ponto ${_nomesPontos.length + 1}';
    final tituloModal = indexAtualizar != null ? 'Editar Medição' : 'Adicionar Medição';
    final subtituloModal = indexAtualizar != null ? (_leituras[indexAtualizar].nomeLeitura ?? '') : novoNomeDefault;

    final timeFormatter = MaskTextInputFormatter(mask: '##:##', filter: {"#": RegExp(r'[0-9]')});

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tituloModal, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtituloModal, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildInputDialog('R.E.S (K.Ω.cm)', resCtrl, isNumber: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInputDialog('Hora', horaCtrl, formatters: [timeFormatter])),
                  const SizedBox(width: 8),
                  Expanded(child: _buildInputDialog('Temp ºC', tempCtrl, isNumber: true)),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (indexAtualizar != null)
              OutlinedButton(
                onPressed: () async {
                  final leitura = _leituras[indexAtualizar];
                  if (leitura.id != null) {
                    setState(() => _isLoading = true);
                    await ref.read(resistividadeRepositoryProvider).deletarLeitura(leitura.id!);
                  }
                  setState(() {
                    _leituras.removeAt(indexAtualizar);
                    _verificarSelecaoUI();
                    _hasChanges = true;
                    _isLoading = false;
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Apagar', style: TextStyle(color: Colors.red)),
              )
            else
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
              onPressed: () {
                final resVal = double.tryParse(resCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final tempVal = double.tryParse(tempCtrl.text.replaceAll(',', '.')) ?? 0.0;
                
                setState(() {
                  if (indexAtualizar != null) {
                    _leituras[indexAtualizar] = PontoResistividadeLeituraModel(
                      id: _leituras[indexAtualizar].id,
                      resistividade: resVal,
                      hora: horaCtrl.text,
                      temperatura: tempVal,
                      posX: _leituras[indexAtualizar].posX,
                      posY: _leituras[indexAtualizar].posY,
                      nomeLeitura: _leituras[indexAtualizar].nomeLeitura,
                    );
                  } else {
                    _leituras.add(PontoResistividadeLeituraModel(
                      resistividade: resVal,
                      hora: horaCtrl.text,
                      temperatura: tempVal,
                      posX: posX ?? 0.5,
                      posY: posY ?? 0.5,
                      nomeLeitura: subtituloModal,
                    ));
                  }
                  _verificarSelecaoUI();
                  _pontoSelecionadoUI = subtituloModal; 
                  _hasChanges = true; 
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputDialog(String label, TextEditingController controller, {List<TextInputFormatter>? formatters, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
          inputFormatters: formatters,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true, 
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8), 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
          ),
        ),
      ],
    );
  }

  Future<void> _salvarDados() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarDados`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer. Como
    // o repositório decide INSERT vs UPDATE em `pontos_ensaios_geral` a
    // partir de `_pontoGeralIdAtual` (nulo pra um ponto novo), as duas
    // chamadas cairiam no ramo de INSERT e duplicariam a linha (além de
    // duplicar as leituras em `ponto_ensaio_resistividade_leitura`). Setar
    // `_isLoading` aqui é síncrono (setState muda o campo na hora, só o
    // rebuild é adiado), então a segunda chamada já vê `_isLoading == true`
    // e sai antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      File? fotoGridComPontos = await _gerarImagemGridComPontos();

      List<double> ultimasLeituras = [];
      for (var entry in _leiturasAgrupadas.entries) {
        var leiturasDoGrupo = List<PontoResistividadeLeituraModel>.from(entry.value);
        leiturasDoGrupo.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));
        if (leiturasDoGrupo.isNotEmpty) {
          ultimasLeituras.add(leiturasDoGrupo.last.resistividade);
        }
      }
      
      double mediaGlobal = 0.0;
      if (ultimasLeituras.isNotEmpty) {
        mediaGlobal = ultimasLeituras.reduce((a, b) => a + b) / ultimasLeituras.length;
      }

      // Aplica a regra para gerar o Status e a Cor que vão para a tela inicial
      final avaliacao = _avaliarRisco(mediaGlobal);
      String resultadoBadge = ultimasLeituras.isEmpty ? 'Pendente' : '${mediaGlobal.toStringAsFixed(1)} K.Ω.cm';
      String corBadge = ultimasLeituras.isEmpty ? '#BDBDBD' : avaliacao['hex']; 

      final model = PontoResistividadeCompletoModel(
        idGeral: _pontoGeralIdAtual,
        nomePonto: _nomePontoCtrl.text,
        elementoNome: widget.elementoNome,
        tipoElemento: widget.tipoElemento,
        criadoEm: DateTime.now().toIso8601String(), 
        resultado: resultadoBadge,                  
        resultadoCor: corBadge,
        local: widget.local,
        leituras: _leituras,
        urlFotoElemento: _urlFotoElemento,
        urlFotoRealizando: _urlFotoRealizando,
        urlFotoGrid: _urlFotoGrid,
      );

      final resultados = await ref.read(resistividadeRepositoryProvider).salvarPonto(
        dados: model,
        projetoId: widget.projetoId,
        elementoId: widget.elementoId,
        tipoEnsaioId: widget.tipoEnsaioId,
        fotoElementoNova: _fotoElementoLocal,
        fotoRealizandoNova: _fotoRealizandoLocal,
        fotoGridNova: _fotoGridLocal,
        fotoGridComPontosNova: fotoGridComPontos, 
      );

      if (mounted) {
        setState(() {
          _pontoGeralIdAtual = resultados['pontoGeralId'];
          _hasChanges = false;
        });
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      }
      // <-- INVALIDE O PROVIDER AQUI PARA RECARREGAR A TELA ANTERIOR -->
      // Caso sua tela de pontos geral use este provider específico (ajuste se usar outro nome):
      try {
        ref.invalidate(resumoEnsaiosProvider);
      } catch(_) {}

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final permissoes = ref.watch(ensaioPermissoesProvider(_pontoGeralIdAtual ?? '')).value ?? EnsaioPermissoes.somenteVisualizar;

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
          title: 'Ponto de\nEnsaio',
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
              label: 'Fotos', onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop(); 
              if (_pontoGeralIdAtual == null || _hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange),
                );
                return;
                }
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => GaleriaEnsaioScreen(
                      pontoGeralId: _pontoGeralIdAtual!,
                      pontoNome: _nomePontoCtrl.text,
                      elementoNome: widget.elementoNome,
                      tipoElemento: widget.tipoElemento,
                      local: widget.local,
                      tipoEnsaio: widget.tipoEnsaioId,
                    ),
                  ),
                );
              }, 
            ),
            
            DiaviconMenuItem(icon: Icons.show_chart_rounded, label: 'Análise', onTap: () {
              Navigator.pop(context); 
                if (_pontoGeralIdAtual == null || _hasChanges) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Salve o ponto primeiro para visualizar a análise.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalisePontoEnsaioResistividadeScreen(
                      pontoGeralId: _pontoGeralIdAtual!,
                    ),
                  ),
                );
            }),
            
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

      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            const Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Resistividade Elétrica', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                      ? TextField(controller: _nomePontoCtrl, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold), onSubmitted: (_) => setState(() => _isEditingName = false))
                      : Text('${_nomePontoCtrl.text} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (permissoes.canEdit)
                  IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
              ],
            ),
            Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            Text(widget.local, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),

            // --- FOTOS ELEMENTO/REALIZANDO ---
            Row(
              children: [
                Expanded(child: _buildFotoCard('Elemento Estrutural', _fotoElementoLocal, _urlFotoElemento, () => _capturarFoto(1))),
                const SizedBox(width: 16),
                Expanded(child: _buildFotoCard('Realizando Ensaio', _fotoRealizandoLocal, _urlFotoRealizando, () => _capturarFoto(2))),
              ],
            ),
            const SizedBox(height: 24),

            // --- GRID INTERATIVO ---
            Text('Marcação dos pontos de leitura', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 12),
            _buildInteractiveGrid(),
            const SizedBox(height: 24),

            // --- ÁREA DO GRÁFICO E MEDIÇÕES ---
            if (_nomesPontos.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ponto de Leitura', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  ElevatedButton(
                    onPressed: () => _abrirModalLeitura(posX: 0.5, posY: 0.5), 
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Novo Ponto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _pontoSelecionadoUI,
                    items: _nomesPontos.map((nome) => DropdownMenuItem(value: nome, child: Text(nome))).toList(),
                    onChanged: (val) => setState(() => _pontoSelecionadoUI = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GRÁFICO
              SizedBox(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: NumericAxis(
                    title: AxisTitle(text: 'Tempo Decorrido (HH:mm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLabelFormatter: (AxisLabelRenderDetails details) {
                      final int totalMin = details.value.toInt();
                      final String h = (totalMin ~/ 60).toString().padLeft(2, '0');
                      final String m = (totalMin % 60).toString().padLeft(2, '0');
                      return ChartAxisLabel('$h:$m', details.textStyle);
                    },
                  ),
                  primaryYAxis: NumericAxis(
                    title: AxisTitle(text: 'Resistividade (K.Ω.cm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                  ),
                  legend: Legend(isVisible: true, position: LegendPosition.top),
                  series: _leiturasAgrupadas.entries.map((entry) {
                    final data = List<PontoResistividadeLeituraModel>.from(entry.value);
                    data.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));
                    final horaInicial = data.isNotEmpty ? data.first.hora : '00:00';
                    
                    return LineSeries<PontoResistividadeLeituraModel, num>(
                      name: entry.key,
                      dataSource: data,
                      xValueMapper: (datum, index) => _getDeltaMinutes(datum.hora, horaInicial),
                      yValueMapper: (datum, index) => datum.resistividade,
                      markerSettings: const MarkerSettings(isVisible: true),
                      width: entry.key == _pontoSelecionadoUI ? 3.5 : 1.5,
                      color: entry.key == _pontoSelecionadoUI ? const Color(0xFFFFA726) : Colors.grey.shade400,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // GALERIA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Histórico de Leituras - $_pontoSelecionadoUI', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    
                    _buildLeiturasCards(),
                    
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 16),

                    _buildLocalVariation(),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SUMÁRIO GLOBAL
              Text('Consolidado do Ensaio (Últimas Leituras)', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              const SizedBox(height: 12),
              _buildGlobalSummary(),

            ] else ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _abrirModalLeitura(posX: 0.5, posY: 0.5),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Iniciar Primeira Leitura', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
                ),
              )
            ],
                ],
              ),
            ),

            const SizedBox(height: 48),

            // --- SALVAR ---
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

  // Em tela larga a caixa de altura fixa virava uma faixa fina e cortada.
  // A largura fica limitada; no celular (mais estreito que isso) nada muda,
  // então os pontos já marcados em campo continuam no mesmo lugar.
  Widget _buildInteractiveGrid() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _buildInteractiveGridConteudo(),
      ),
    );
  }

  Widget _buildInteractiveGridConteudo() {
    ImageProvider? gridImage;
    if (_fotoGridLocal != null) {
      gridImage = FileImage(_fotoGridLocal!);
    } else if (_urlFotoGrid != null && _urlFotoGrid!.isNotEmpty) {
      gridImage = StorageNetworkImage(_urlFotoGrid!);
    }

    if (gridImage == null) {
      return GestureDetector(
        onTap: () => _capturarFoto(3),
        child: Container(
          height: 250, width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Adicionar Imagem do Grid', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 350,
      width: double.infinity,
      clipBehavior: Clip.hardEdge, 
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RepaintBoundary(
        key: _gridRepaintKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: gridImage,
              fit: BoxFit.cover,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: (details) {
                    final box = context.findRenderObject() as RenderBox;
                    final localPos = box.globalToLocal(details.globalPosition);
                    final xPerc = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                    final yPerc = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);
                    _abrirModalLeitura(posX: xPerc, posY: yPerc); 
                  },
                  child: Container(color: Colors.transparent),
                );
              },
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: _leiturasAgrupadas.keys.map((nomePonto) {
                    final leiturasDoPonto = _leiturasAgrupadas[nomePonto]!;
                    final primeiraLeitura = leiturasDoPonto.first;
                    final numeroVisual = nomePonto.replaceAll(RegExp(r'[^0-9]'), '');

                    return Positioned(
                      left: (primeiraLeitura.posX * constraints.maxWidth) - 15, 
                      top: (primeiraLeitura.posY * constraints.maxHeight) - 15,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          setState(() {
                            double novoX = primeiraLeitura.posX + (details.delta.dx / constraints.maxWidth);
                            double novoY = primeiraLeitura.posY + (details.delta.dy / constraints.maxHeight);
                            
                            novoX = novoX.clamp(0.0, 1.0);
                            novoY = novoY.clamp(0.0, 1.0);

                            for (var leitura in _leituras) {
                              if (leitura.nomeLeitura == nomePonto) {
                                leitura.posX = novoX;
                                leitura.posY = novoY;
                              }
                            }
                            _pontoSelecionadoUI = nomePonto; 
                            _hasChanges = true;
                          });
                        },
                        onTap: () {
                           setState(() => _pontoSelecionadoUI = nomePonto);
                        },
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: _pontoSelecionadoUI == nomePonto ? Colors.redAccent : const Color(0xFFFFA726),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Center(
                            child: Text(numeroVisual.isNotEmpty ? numeroVisual : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            Positioned(
              bottom: 12, right: 12,
              child: GestureDetector(
                onTap: () => _capturarFoto(3),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeiturasCards() {
    final leiturasAtuais = _leiturasAgrupadas[_pontoSelecionadoUI] ?? [];
    leiturasAtuais.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(leiturasAtuais.length, (index) {
          final l = leiturasAtuais[index];
          final indexGeral = _leituras.indexOf(l);

          return GestureDetector(
            onTap: () => _abrirModalLeitura(indexAtualizar: indexGeral),
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${l.resistividade.toStringAsFixed(0)}\nK.Ω.cm', textAlign: TextAlign.center, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF3E3E3D), height: 1.1)),
                  const SizedBox(height: 6),
                  Text(l.hora, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLocalVariation() {
    final leiturasAtuais = _leiturasAgrupadas[_pontoSelecionadoUI] ?? [];
    leiturasAtuais.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));

    double variacao = 0.0;
    bool possuiHistoricoSuficiente = leiturasAtuais.length >= 2;
    
    if (possuiHistoricoSuficiente) {
      double ultimo = leiturasAtuais.last.resistividade;
      double penultimo = leiturasAtuais[leiturasAtuais.length - 2].resistividade;

      if (penultimo != 0) {
        variacao = (1 - (ultimo / penultimo)).abs() * 100;
      }
    }

    final isEstabilizado = variacao <= 10.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Variação de estabilidade', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              if (possuiHistoricoSuficiente) ...[
                Row(
                  children: [
                    Text('${variacao.toStringAsFixed(1)}%', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isEstabilizado ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        isEstabilizado ? 'Estável' : 'Instável',
                        style: TextStyle(fontSize: 10, color: isEstabilizado ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text('Entre as 2 últimas leituras', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ] else ...[
                const Text('Adicione +1 leitura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
              ]
            ],
          ),
        ),
        
        GestureDetector(
          onTap: () => _abrirModalLeitura(nomePontoParaAdicionar: _pontoSelecionadoUI),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA726),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                const Icon(Icons.add, color: Colors.white, size: 18),
                const SizedBox(width: 4),
                Text('Nova', style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Novo Sumário Global contendo a terceira seção "Condição" atrelada à cor do badge
  Widget _buildGlobalSummary() {
    List<double> ultimasLeituras = [];
    
    for (var entry in _leiturasAgrupadas.entries) {
      var leiturasDoGrupo = List<PontoResistividadeLeituraModel>.from(entry.value);
      leiturasDoGrupo.sort((a, b) => _parseTime(a.hora).compareTo(_parseTime(b.hora)));
      
      if (leiturasDoGrupo.isNotEmpty) {
        ultimasLeituras.add(leiturasDoGrupo.last.resistividade);
      }
    }

    double media = 0.0;
    double coefVar = 0.0;
    
    if (ultimasLeituras.isNotEmpty) {
      final soma = ultimasLeituras.reduce((a, b) => a + b);
      media = soma / ultimasLeituras.length;

      if (ultimasLeituras.length > 1 && media > 0) {
        double variance = ultimasLeituras.map((e) => pow(e - media, 2)).reduce((a, b) => a + b) / ultimasLeituras.length;
        coefVar = (sqrt(variance) / media) * 100;
      }
    }

    final isHomogeneo = coefVar <= 15.0;
    final condicao = _avaliarRisco(media); // 👈 Invoca a condicional de Risco

    return Row(
      children: [
        // 1. Média
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                const Text('Média', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text('${media.toStringAsFixed(1)} K.Ω.cm', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Variação
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                const Text('Variação', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${coefVar.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                        style: TextStyle(fontSize: 9, color: isHomogeneo ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 3. Condição (Novo Card de Badge)
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                const Text('Risco de Corrosão', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (condicao['cor'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    condicao['texto'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: condicao['cor'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFotoCard(String titulo, File? fotoLocal, String? urlRemota, VoidCallback onTap) {
    ImageProvider? imageProvider;
    if (fotoLocal != null) {
      imageProvider = FileImage(fotoLocal);
    } else if (urlRemota != null && urlRemota.isNotEmpty) {
      imageProvider = StorageNetworkImage(urlRemota);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(titulo, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        // Proporção fixa em vez de altura fixa: a foto não achata em tela larga.
        // Tocar continua capturando/trocando a foto.
        FotoEnsaio(
          imagem: imageProvider,
          raio: 16,
          aoTocar: onTap,
          vazio: const Center(child: Icon(Icons.camera_alt, color: Colors.grey)),
          acao: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_square, size: 20, color: Color(0xFF3E3E3D)),
          ),
        ),
      ],
    );
  }
}