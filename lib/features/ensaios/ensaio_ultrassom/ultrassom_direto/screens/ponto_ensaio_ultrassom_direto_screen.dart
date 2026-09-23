import 'package:diavicon/core/services/storage_urls.dart';
import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/custom_appbar.dart';
import '../../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../ensaios_geral/providers/ensaios_provider.dart';
import '../../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/ultrassom_direto_model.dart';
import '../repositories/ultrassom_direto_repository.dart';
import '../utils/marcacao_pontos_renderer.dart';
import '../widgets/whitehurst_info_dialog.dart';
import 'analise_ponto_ultrassom_direto_screen.dart';
import '../../../../../core/web/escolher_foto.dart';

// Coleta do ensaio de Ultrassonografia — método Direto. Mesmo padrão de
// `PontoEnsaioResistividadeScreen` (marcação de N pontos numa foto,
// arrastáveis, com um dropdown de seleção + leituras por ponto), com uma
// diferença estrutural: aqui cada ponto marcado é sua PRÓPRIA entidade
// (`ponto_ensaio_ultrassom_direto_medicao`, com nome/distância/posição
// próprios), não só um agrupamento por nome dentro da leitura — porque o
// usuário pediu essas tabelas separadas (medição 1:N leitura).
class PontoEnsaioUltrassomDiretoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;
  final String pulsoUltrassonico;

  const PontoEnsaioUltrassomDiretoScreen({
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
  ConsumerState<PontoEnsaioUltrassomDiretoScreen> createState() => _PontoEnsaioUltrassomDiretoScreenState();
}

class _PontoEnsaioUltrassomDiretoScreenState extends ConsumerState<PontoEnsaioUltrassomDiretoScreen> {
  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;

  late TextEditingController _nomePontoCtrl;
  final TextEditingController _velocidadeCtrl = TextEditingController();

  List<PontoMedicaoUltrassomDiretoModel> _medicoes = [];
  String? _pontoSelecionadoNome;

  late String _pulsoSelecionado;
  static const List<String> _opcoesPulso = ['Longitudinal', 'Transversal'];

  String? _idUltrassomAtual;
  File? _foto1Local;
  File? _foto2Local;
  File? _foto3Local;
  String? _urlFoto1;
  String? _urlFoto2;
  String? _urlFoto3;

  String? _pontoGeralIdAtual;

  @override
  void initState() {
    super.initState();
    _nomePontoCtrl = TextEditingController(text: widget.pontoNome);
    _pulsoSelecionado = _opcoesPulso.contains(widget.pulsoUltrassonico) ? widget.pulsoUltrassonico : 'Longitudinal';
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
    _velocidadeCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  List<String> get _nomesPontos {
    final nomes = _medicoes.map((m) => m.nomePonto).toList();
    nomes.sort();
    return nomes;
  }

  PontoMedicaoUltrassomDiretoModel? get _medicaoSelecionada {
    if (_pontoSelecionadoNome == null) return null;
    for (final m in _medicoes) {
      if (m.nomePonto == _pontoSelecionadoNome) return m;
    }
    return null;
  }

  void _verificarSelecao() {
    final nomes = _nomesPontos;
    if (nomes.isEmpty) {
      _pontoSelecionadoNome = null;
    } else if (_pontoSelecionadoNome == null || !nomes.contains(_pontoSelecionadoNome)) {
      _pontoSelecionadoNome = nomes.first;
    }
  }

  Future<void> _carregarDadosExistentes() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }
    try {
      final repo = ref.read(ultrassomDiretoRepositoryProvider);
      final dados = await repo.buscarPontoUltrassom(_pontoGeralIdAtual!);
      if (dados != null) {
        _idUltrassomAtual = dados.id;
        _urlFoto1 = dados.foto1;
        _urlFoto2 = dados.foto2;
        _urlFoto3 = dados.foto3;
        _medicoes = dados.medicoes;
        if (_opcoesPulso.contains(dados.pulsoUltrassonico)) _pulsoSelecionado = dados.pulsoUltrassonico;
        _verificarSelecao();
      }

      final supabase = Supabase.instance.client;
      final geralResp = await supabase.from('pontos_ensaios_geral').select('nome_ponto').eq('id', _pontoGeralIdAtual!).maybeSingle();
      if (geralResp != null) _nomePontoCtrl.text = geralResp['nome_ponto'] ?? widget.pontoNome;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar: $e')));
    } finally {
      if (mounted) setState(() { _isInitializing = false; _hasChanges = false; });
    }
  }

  Future<void> _capturarFoto(int referencia) async {
    final source = origemFotoNoNavegador ?? await showModalBottomSheet<ImageSource>(
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
    if (source == null) return;
    final image = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (image == null) return;
    setState(() {
      if (referencia == 1) _foto1Local = File(image.path);
      if (referencia == 2) _foto2Local = File(image.path);
      if (referencia == 3) _foto3Local = File(image.path);
      _hasChanges = true;
    });
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
      await ref.read(ultrassomDiretoRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
      if (mounted) {
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponto excluído com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // `medicaoExistente` != null => modo edição (nome/distância + Apagar),
  // igual ao padrão de editar/apagar leitura já usado abaixo.
  Future<void> _abrirModalNovoPonto({
    required double posX,
    required double posY,
    PontoMedicaoUltrassomDiretoModel? medicaoExistente,
  }) async {
    final ehEdicao = medicaoExistente != null;
    final nomeCtrl = TextEditingController(text: medicaoExistente?.nomePonto ?? 'Ponto ${_medicoes.length + 1}');
    final distCtrl = TextEditingController(text: medicaoExistente?.distancia != null ? medicaoExistente!.distancia!.toStringAsFixed(0) : '');

    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ehEdicao ? 'Editar ponto de medição' : 'Novo ponto de medição', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do ponto')),
            const SizedBox(height: 12),
            TextField(
              controller: distCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Distância entre transdutores (cm)'),
            ),
          ],
        ),
        actionsAlignment: ehEdicao ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
        actions: [
          if (ehEdicao)
            TextButton(onPressed: () => Navigator.pop(context, 'apagar'), child: const Text('Apagar', style: TextStyle(color: Colors.red)))
          else
            TextButton(onPressed: () => Navigator.pop(context, 'cancelar'), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
            onPressed: () => Navigator.pop(context, 'salvar'),
            child: Text(ehEdicao ? 'Salvar' : 'Criar', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (acao == 'apagar' && medicaoExistente != null) {
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir ponto de medição'),
          content: Text('Deseja realmente excluir "${medicaoExistente.nomePonto}" e todas as suas leituras?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirmar != true) return;

      if (medicaoExistente.id != null) {
        setState(() => _isLoading = true);
        await ref.read(ultrassomDiretoRepositoryProvider).deletarPontoMedicao(medicaoExistente.id!);
      }
      setState(() {
        _medicoes.remove(medicaoExistente);
        _verificarSelecao();
        _hasChanges = true;
        _isLoading = false;
      });
      return;
    }

    if (acao != 'salvar' || nomeCtrl.text.trim().isEmpty) return;
    final novoNome = nomeCtrl.text.trim();
    final novaDistancia = double.tryParse(distCtrl.text.replaceAll(',', '.'));

    setState(() {
      if (ehEdicao) {
        medicaoExistente.nomePonto = novoNome;
        medicaoExistente.distancia = novaDistancia;
        _pontoSelecionadoNome = novoNome;
      } else {
        _medicoes.add(PontoMedicaoUltrassomDiretoModel(
          nomePonto: novoNome,
          distancia: novaDistancia,
          posX: posX,
          posY: posY,
          leituras: [],
        ));
        _pontoSelecionadoNome = novoNome;
      }
      _hasChanges = true;
    });
  }

  void _adicionarLeitura() {
    final medicao = _medicaoSelecionada;
    if (medicao == null) return;
    final velocidade = double.tryParse(_velocidadeCtrl.text.replaceAll(',', '.'));
    if (velocidade == null || velocidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe uma velocidade válida.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      medicao.leituras.add(LeituraUltrassomDiretoModel(velocidade: velocidade));
      _velocidadeCtrl.clear();
      _hasChanges = true;
    });
  }

  Future<void> _editarOuApagarLeitura(PontoMedicaoUltrassomDiretoModel medicao, int index) async {
    final leitura = medicao.leituras[index];
    final ctrl = TextEditingController(text: leitura.velocidade.toStringAsFixed(0));

    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar leitura', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Velocidade (m/s)'),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'apagar'), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726)),
            onPressed: () => Navigator.pop(context, 'salvar'),
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (acao == 'apagar') {
      if (leitura.id != null) {
        setState(() => _isLoading = true);
        await ref.read(ultrassomDiretoRepositoryProvider).deletarLeitura(leitura.id!);
      }
      setState(() {
        medicao.leituras.removeAt(index);
        _hasChanges = true;
        _isLoading = false;
      });
    } else if (acao == 'salvar') {
      final novaVelocidade = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (novaVelocidade == null || novaVelocidade <= 0) return;
      setState(() {
        leitura.velocidade = novaVelocidade;
        _hasChanges = true;
      });
    }
  }

  // A foto "Pontos de leitura marcados" (foto_3) precisa ir pro banco JÁ com
  // os círculos numerados desenhados nela — o overlay ao vivo em
  // `_buildInteractiveGrid` é só um widget `Positioned` por cima da tela,
  // nunca fica gravado no arquivo. Sempre recompõe no save (a partir da
  // foto nova, se o usuário trocou, ou baixando a já salva) pra garantir
  // que a imagem exportada acompanhe a posição atual dos pontos, inclusive
  // depois de arrastar um pino sem trocar de foto.
  Future<File?> _prepararFoto3ComMarcacoes() async {
    if (_medicoes.isEmpty) return _foto3Local;
    try {
      final Uint8List bytesBase;
      if (_foto3Local != null) {
        bytesBase = await _foto3Local!.readAsBytes();
      } else if (_urlFoto3 != null && _urlFoto3!.isNotEmpty) {
        final resposta = await StorageUrls.baixar(_urlFoto3!);
        if (resposta.statusCode != 200) return _foto3Local;
        bytesBase = resposta.bodyBytes;
      } else {
        return _foto3Local;
      }
      return await MarcacaoPontosRenderer.compor(bytesFotoBase: bytesBase, medicoes: _medicoes);
    } catch (_) {
      return _foto3Local;
    }
  }

  Future<void> _salvarDados() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarDados`) a partir do PRÓXIMO
    // rebuild/frame. Num toque duplo rápido, a segunda chamada ainda acha o
    // botão habilitado e entra aqui de novo antes do rebuild acontecer. Como
    // o repositório decide INSERT vs UPDATE em `pontos_ensaios_geral` e
    // `ponto_ensaio_ultrassom` a partir de `_pontoGeralIdAtual`/
    // `_idUltrassomAtual` (nulos pra um ponto novo), as duas chamadas
    // cairiam no ramo de INSERT e duplicariam as linhas. Setar `_isLoading`
    // aqui é síncrono (setState muda o campo na hora, só o rebuild é
    // adiado), então a segunda chamada já vê `_isLoading == true` e sai
    // antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final foto3ComMarcacoes = await _prepararFoto3ComMarcacoes();

      final dados = PontoUltrassomDiretoModel(
        id: _idUltrassomAtual,
        pontoGeralId: _pontoGeralIdAtual,
        pulsoUltrassonico: _pulsoSelecionado,
        foto1: _urlFoto1,
        foto2: _urlFoto2,
        foto3: _urlFoto3,
        medicoes: _medicoes,
      );

      final resultado = await ref.read(ultrassomDiretoRepositoryProvider).salvarPontoCompleto(
            dados: dados,
            projetoId: widget.projetoId,
            elementoId: widget.elementoId,
            tipoEnsaioId: widget.tipoEnsaioId,
            pontoNome: _nomePontoCtrl.text.trim(),
            foto1Nova: _foto1Local,
            foto2Nova: _foto2Local,
            foto3Nova: foto3ComMarcacoes,
          );

      if (mounted) {
        setState(() {
          _pontoGeralIdAtual = resultado['pontoGeralId'];
          _idUltrassomAtual = resultado['idUltrassom'];
          _hasChanges = false;
        });
        ref.invalidate(resumoEnsaiosProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
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
    final medicaoSelecionada = _medicaoSelecionada;

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
              navigator.push(MaterialPageRoute(
                builder: (context) => GaleriaEnsaioScreen(
                  pontoGeralId: _pontoGeralIdAtual!,
                  pontoNome: _nomePontoCtrl.text,
                  elementoNome: widget.elementoNome,
                  tipoElemento: widget.tipoElemento,
                  local: widget.local,
                  tipoEnsaio: widget.tipoEnsaioId,
                ),
              ));
            },
          ),
          DiaviconMenuItem(
            icon: Icons.show_chart_rounded,
            label: 'Análise',
            onTap: () {
              Navigator.pop(context);
              if (_pontoGeralIdAtual == null || _hasChanges) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve o ponto primeiro para visualizar a análise.'), backgroundColor: Colors.orange));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (context) => AnalisePontoUltrassomDiretoScreen(pontoGeralId: _pontoGeralIdAtual!)));
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
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        titleWidget: Column(
          children: [
            const Text('Ponto de ensaio', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            const Text('Ultrassonografia - Método direto', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                    Expanded(child: Text('Somente visualização — apenas a empresa que criou este ensaio pode editá-lo.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
                  ],
                ),
              ),
            AbsorbPointer(
              absorbing: !permissoes.canEdit,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  TextField(controller: _nomePontoCtrl, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold), onSubmitted: (_) => setState(() => _isEditingName = false)),
                                  const SizedBox(height: 8),
                                  _buildPulsoDropdownInline(),
                                ],
                              )
                            : Text('${_nomePontoCtrl.text} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      if (permissoes.canEdit) IconButton(icon: Icon(_isEditingName ? Icons.check : Icons.edit_square), onPressed: () => setState(() => _isEditingName = !_isEditingName)),
                    ],
                  ),
                  Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
                  Text(widget.local, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
                  if (!_isEditingName) Text('Pulso ${_pulsoSelecionado.toLowerCase()}', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(child: _buildFotoCard('Marcação da área', _foto1Local, _urlFoto1, () => _capturarFoto(1))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFotoCard('Realização do Ensaio', _foto2Local, _urlFoto2, () => _capturarFoto(2))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text('Marcação dos pontos de leitura', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  const SizedBox(height: 12),
                  _buildInteractiveGrid(),
                  const SizedBox(height: 24),

                  if (_nomesPontos.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ponto de Leitura', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        ElevatedButton(
                          onPressed: () => _abrirModalNovoPonto(posX: 0.5, posY: 0.5),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text('Novo Ponto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _pontoSelecionadoNome,
                                items: _nomesPontos.map((nome) => DropdownMenuItem(value: nome, child: Text(nome))).toList(),
                                onChanged: (val) => setState(() => _pontoSelecionadoNome = val),
                              ),
                            ),
                          ),
                        ),
                        if (medicaoSelecionada != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _abrirModalNovoPonto(posX: medicaoSelecionada.posX, posY: medicaoSelecionada.posY, medicaoExistente: medicaoSelecionada),
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3E3E3D)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _velocidadeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Velocidade (m/s)',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _adicionarLeitura,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(color: Color(0xFFFFA726), shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (medicaoSelecionada != null) _buildResumoPonto(medicaoSelecionada),
                    const SizedBox(height: 16),

                    if (medicaoSelecionada != null) _buildLeiturasCards(medicaoSelecionada),
                  ] else
                    Center(
                      child: Text('Toque na foto acima pra marcar o primeiro ponto de leitura.', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            if (_hasChanges && permissoes.canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _salvarDados,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
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

  Widget _buildResumoPonto(PontoMedicaoUltrassomDiretoModel medicao) {
    final media = medicao.media;
    final cv = medicao.coefVariacao;
    final classificacao = ClassificacaoWhitehurst.classificar(media);
    final isHomogeneo = cv <= 15.0;

    return Row(
      children: [
        Expanded(child: _cardResumo('Média', media > 0 ? '${media.toStringAsFixed(0)} m/s' : '-')),
        const SizedBox(width: 8),
        Expanded(
          child: _cardResumo(
            'C.Var',
            medicao.leituras.length >= 2 ? '${cv.toStringAsFixed(0)}%' : '-',
            corFundo: medicao.leituras.length >= 2 ? (isHomogeneo ? Colors.green.shade50 : Colors.red.shade50) : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => showWhitehurstInfoDialog(context),
            child: _cardResumo('Classificação', classificacao.texto, corTexto: classificacao.cor, iconeInfo: true),
          ),
        ),
      ],
    );
  }

  Widget _cardResumo(String label, String valor, {Color? corFundo, Color? corTexto, bool iconeInfo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: corFundo ?? Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (iconeInfo) ...[const SizedBox(width: 3), Icon(Icons.info_outline, size: 11, color: Colors.grey.shade400)],
            ],
          ),
          const SizedBox(height: 4),
          Text(valor, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: corTexto ?? const Color(0xFF3E3E3D))),
        ],
      ),
    );
  }

  Widget _buildLeiturasCards(PontoMedicaoUltrassomDiretoModel medicao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(medicao.leituras.length, (index) {
        final l = medicao.leituras[index];
        return InkWell(
          onTap: () => _editarOuApagarLeitura(medicao, index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Leitura ${index + 1}', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF3E3E3D))),
                Text('${l.velocidade.toStringAsFixed(0)} m/s', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ),
        );
      }),
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
    ImageProvider? imagem;
    if (_foto3Local != null) {
      imagem = FileImage(_foto3Local!);
    } else if (_urlFoto3 != null && _urlFoto3!.isNotEmpty) {
      imagem = StorageNetworkImage(_urlFoto3!);
    }

    if (imagem == null) {
      return GestureDetector(
        onTap: () => _capturarFoto(3),
        child: Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Adicionar foto pra marcar os pontos', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 350,
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: imagem, fit: BoxFit.cover),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapUp: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  final xPerc = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
                  final yPerc = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);
                  _abrirModalNovoPonto(posX: xPerc, posY: yPerc);
                },
                child: Container(color: Colors.transparent),
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: _medicoes.map((medicao) {
                  final numeroVisual = medicao.nomePonto.replaceAll(RegExp(r'[^0-9]'), '');
                  final selecionado = medicao.nomePonto == _pontoSelecionadoNome;
                  return Positioned(
                    left: (medicao.posX * constraints.maxWidth) - 15,
                    top: (medicao.posY * constraints.maxHeight) - 15,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setState(() {
                          medicao.posX = (medicao.posX + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0);
                          medicao.posY = (medicao.posY + details.delta.dy / constraints.maxHeight).clamp(0.0, 1.0);
                          _pontoSelecionadoNome = medicao.nomePonto;
                          _hasChanges = true;
                        });
                      },
                      onTap: () => setState(() => _pontoSelecionadoNome = medicao.nomePonto),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selecionado ? Colors.redAccent : const Color(0xFFFFA726),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: Center(child: Text(numeroVisual.isNotEmpty ? numeroVisual : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          Positioned(
            bottom: 12,
            right: 12,
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
        // Proporção fixa em vez de altura fixa: a foto não achata em tela
        // larga. Tocar continua trocando a foto.
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
