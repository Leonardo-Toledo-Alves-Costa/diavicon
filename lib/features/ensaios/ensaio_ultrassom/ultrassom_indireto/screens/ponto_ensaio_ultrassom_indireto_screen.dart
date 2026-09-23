import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/widgets/custom_appbar.dart';
import '../../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../../ensaios_geral/providers/ensaios_provider.dart';
import '../../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../../ultrassom_direto/models/ultrassom_direto_model.dart' show ClassificacaoWhitehurst;
import '../../ultrassom_direto/widgets/whitehurst_info_dialog.dart';
import '../models/ultrassom_indireto_model.dart';
import '../repositories/ultrassom_indireto_repository.dart';
import 'analise_ponto_ultrassom_indireto_screen.dart';
import '../../../../../core/web/escolher_foto.dart';

// Coleta do ensaio de Ultrassonografia — método Indireto. Sem marcação em
// foto (o usuário só cria o ponto de leitura pelo nome e começa a coletar
// pares Distância/Velocidade) — o gráfico (tempo x distância) e a
// "velocidade verdadeira"/R² são calculados por regressão linear a partir
// dessas leituras (ver `MedicaoUltrassomIndiretoModel`).
class PontoEnsaioUltrassomIndiretoScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;
  final String pulsoUltrassonico;

  const PontoEnsaioUltrassomIndiretoScreen({
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
  ConsumerState<PontoEnsaioUltrassomIndiretoScreen> createState() => _PontoEnsaioUltrassomIndiretoScreenState();
}

class _PontoEnsaioUltrassomIndiretoScreenState extends ConsumerState<PontoEnsaioUltrassomIndiretoScreen> {
  bool _isEditingName = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _hasChanges = false;

  late TextEditingController _nomePontoCtrl;
  final TextEditingController _distanciaCtrl = TextEditingController();
  final TextEditingController _velocidadeCtrl = TextEditingController();

  List<MedicaoUltrassomIndiretoModel> _medicoes = [];
  String? _pontoSelecionadoNome;

  late String _pulsoSelecionado;
  static const List<String> _opcoesPulso = ['Longitudinal', 'Transversal'];

  String? _idUltrassomAtual;
  File? _foto1Local;
  File? _foto2Local;
  String? _urlFoto1;
  String? _urlFoto2;

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
    _distanciaCtrl.dispose();
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

  MedicaoUltrassomIndiretoModel? get _medicaoSelecionada {
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
      final repo = ref.read(ultrassomIndiretoRepositoryProvider);
      final dados = await repo.buscarPontoUltrassom(_pontoGeralIdAtual!);
      if (dados != null) {
        _idUltrassomAtual = dados.id;
        _urlFoto1 = dados.foto1;
        _urlFoto2 = dados.foto2;
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
      await ref.read(ultrassomIndiretoRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
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

  // `medicaoExistente` != null => modo edição (só o nome — sem distância/
  // posição aqui) + Apagar, mesmo padrão do método Direto.
  Future<void> _abrirModalPonto({MedicaoUltrassomIndiretoModel? medicaoExistente}) async {
    final ehEdicao = medicaoExistente != null;
    final nomeCtrl = TextEditingController(text: medicaoExistente?.nomePonto ?? 'Ponto ${_medicoes.length + 1}');

    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ehEdicao ? 'Editar ponto de medição' : 'Novo ponto de medição', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do ponto')),
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
        await ref.read(ultrassomIndiretoRepositoryProvider).deletarPontoMedicao(medicaoExistente.id!);
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

    setState(() {
      if (ehEdicao) {
        medicaoExistente.nomePonto = novoNome;
        _pontoSelecionadoNome = novoNome;
      } else {
        _medicoes.add(MedicaoUltrassomIndiretoModel(nomePonto: novoNome, leituras: []));
        _pontoSelecionadoNome = novoNome;
      }
      _hasChanges = true;
    });
  }

  void _adicionarLeitura() {
    final medicao = _medicaoSelecionada;
    if (medicao == null) return;
    final distancia = double.tryParse(_distanciaCtrl.text.replaceAll(',', '.'));
    final velocidade = double.tryParse(_velocidadeCtrl.text.replaceAll(',', '.'));
    if (distancia == null || distancia <= 0 || velocidade == null || velocidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe distância e velocidade válidas.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() {
      medicao.leituras.add(LeituraUltrassomIndiretoModel(distancia: distancia, velocidade: velocidade));
      _distanciaCtrl.clear();
      _velocidadeCtrl.clear();
      _hasChanges = true;
    });
  }

  Future<void> _editarOuApagarLeitura(MedicaoUltrassomIndiretoModel medicao, int index) async {
    final leitura = medicao.leituras[index];
    final distCtrl = TextEditingController(text: leitura.distancia.toStringAsFixed(0));
    final velCtrl = TextEditingController(text: leitura.velocidade.toStringAsFixed(0));

    final acao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar leitura', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Row(
          children: [
            Expanded(child: TextField(controller: distCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'D (cm)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: velCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Velocidade (m/s)'))),
          ],
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
        await ref.read(ultrassomIndiretoRepositoryProvider).deletarLeitura(leitura.id!);
      }
      setState(() {
        medicao.leituras.removeAt(index);
        _hasChanges = true;
        _isLoading = false;
      });
    } else if (acao == 'salvar') {
      final novaDist = double.tryParse(distCtrl.text.replaceAll(',', '.'));
      final novaVel = double.tryParse(velCtrl.text.replaceAll(',', '.'));
      if (novaDist == null || novaDist <= 0 || novaVel == null || novaVel <= 0) return;
      setState(() {
        leitura.distancia = novaDist;
        leitura.velocidade = novaVel;
        _hasChanges = true;
      });
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
      final dados = PontoUltrassomIndiretoModel(
        id: _idUltrassomAtual,
        pontoGeralId: _pontoGeralIdAtual,
        pulsoUltrassonico: _pulsoSelecionado,
        foto1: _urlFoto1,
        foto2: _urlFoto2,
        medicoes: _medicoes,
      );

      final resultado = await ref.read(ultrassomIndiretoRepositoryProvider).salvarPontoCompleto(
            dados: dados,
            projetoId: widget.projetoId,
            elementoId: widget.elementoId,
            tipoEnsaioId: widget.tipoEnsaioId,
            pontoNome: _nomePontoCtrl.text.trim(),
            foto1Nova: _foto1Local,
            foto2Nova: _foto2Local,
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
              Navigator.push(context, MaterialPageRoute(builder: (context) => AnalisePontoUltrassomIndiretoScreen(pontoGeralId: _pontoGeralIdAtual!)));
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
            const Text('Ultrassonografia - Método Indireto', style: TextStyle(fontSize: 12, color: Colors.white70)),
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

                  Text('Ultrassonografia - Método Indireto', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset('assets/images/ensaios/ultrassonografia/indireto.png', width: double.infinity, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ponto de Leitura', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                      ElevatedButton(
                        onPressed: () => _abrirModalPonto(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text('Novo Ponto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_nomesPontos.isEmpty)
                    Center(child: Text('Toque em "Novo Ponto" pra começar a coletar.', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey)))
                  else ...[
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
                            onTap: () => _abrirModalPonto(medicaoExistente: medicaoSelecionada),
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

                    if (medicaoSelecionada != null) _buildGrafico(medicaoSelecionada),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _distanciaCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'D (cm)', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _velocidadeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Velocidade (m/s)', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
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
                  ],
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

  Widget _buildGrafico(MedicaoUltrassomIndiretoModel medicao) {
    final pontos = [...medicao.leituras]..sort((a, b) => a.distancia.compareTo(b.distancia));
    if (pontos.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(16)),
        child: Text('Adicione leituras pra ver o gráfico.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)]),
      child: SizedBox(
        height: 220,
        child: SfCartesianChart(
          primaryXAxis: NumericAxis(title: AxisTitle(text: 'Distância (cm)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)), majorGridLines: const MajorGridLines(width: 0)),
          primaryYAxis: NumericAxis(title: AxisTitle(text: 'Tempo de propagação do pulso (µs)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)), axisLine: const AxisLine(width: 0)),
          series: <CartesianSeries>[
            LineSeries<LeituraUltrassomIndiretoModel, double>(
              dataSource: pontos,
              xValueMapper: (l, _) => l.distancia,
              yValueMapper: (l, _) => l.tempoMicrossegundos,
              color: const Color(0xFFFFA726),
              markerSettings: const MarkerSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoPonto(MedicaoUltrassomIndiretoModel medicao) {
    final temRegressao = medicao.leituras.length >= 2;
    final velocidade = medicao.valorVelocidade;
    final r2 = medicao.correlacao;
    final classificacao = ClassificacaoWhitehurst.classificar(velocidade);

    return Row(
      children: [
        Expanded(child: _cardResumo('Velocidade', temRegressao ? '${velocidade.toStringAsFixed(0)} m/s' : '-')),
        const SizedBox(width: 8),
        Expanded(child: _cardResumo('R²', temRegressao ? '${(r2 * 100).toStringAsFixed(0)}%' : '-')),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => showWhitehurstInfoDialog(context),
            child: _cardResumo('Classificação', temRegressao ? classificacao.texto : '-', corTexto: temRegressao ? classificacao.cor : null, iconeInfo: true),
          ),
        ),
      ],
    );
  }

  Widget _cardResumo(String label, String valor, {Color? corTexto, bool iconeInfo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
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

  Widget _buildLeiturasCards(MedicaoUltrassomIndiretoModel medicao) {
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
                Text('${l.distancia.toStringAsFixed(0)} cm', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade700)),
                Text('${l.velocidade.toStringAsFixed(0)} m/s', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ),
        );
      }),
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
