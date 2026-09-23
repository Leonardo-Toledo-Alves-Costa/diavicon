import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:diavicon/core/widgets/foto_ensaio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/ensaio_permissoes_provider.dart';
import '../../ensaios_geral/screens/galeria_ensaio_screen.dart';
import '../models/monitoramento_fissura_model.dart';
import '../repositories/monitoramento_fissura_repository.dart';
import '../widgets/nova_medicao_modal.dart';
import 'analise_ponto_monitoramento_fissura_screen.dart';
import '../../../../core/web/escolher_foto.dart';

// Tela de coleta de Monitoramento de Fissuras — instalação (editável a
// qualquer momento) + lista de medições sempre juntas na MESMA tela, igual
// ao resto do app (Potencial/Ultrassom: um formulário só, com tudo visível,
// sem uma etapa "criar" separada de uma etapa "analisar"). Os gráficos
// (movimento em torno do eixo, deslocamento ao longo do tempo) ficam na
// tela de Análise, acessível pelo drawer — mesmo padrão dos outros ensaios
// (coleta x análise em telas separadas).
class PontoMonitoramentoFissuraScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String pontoNome;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String elementoId;
  final String? pontoGeralId;
  final String tipoEnsaioId;

  const PontoMonitoramentoFissuraScreen({
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
  ConsumerState<PontoMonitoramentoFissuraScreen> createState() => _PontoMonitoramentoFissuraScreenState();
}

class _PontoMonitoramentoFissuraScreenState extends ConsumerState<PontoMonitoramentoFissuraScreen> {
  bool _isInitializing = true;
  bool _isLoading = false;
  bool _hasChanges = false;

  String? _pontoGeralIdAtual;
  String? _instalacaoId;
  List<MedicaoFissuraModel> _medicoes = [];

  DateTime _dataInstalacao = DateTime.now();
  final _horaInstalacaoCtrl = TextEditingController();
  final _minutoInstalacaoCtrl = TextEditingController();
  TipoSeloFissura _seloSelecionado = TipoSeloFissura.gesso;
  File? _foto1Local;
  File? _foto2Local;
  String? _urlFoto1;
  String? _urlFoto2;

  DateTime get _dataHoraInstalacao {
    final hora = (int.tryParse(_horaInstalacaoCtrl.text) ?? 0).clamp(0, 23);
    final minuto = (int.tryParse(_minutoInstalacaoCtrl.text) ?? 0).clamp(0, 59);
    return DateTime(_dataInstalacao.year, _dataInstalacao.month, _dataInstalacao.day, hora, minuto);
  }

  void _definirDataHoraInstalacao(DateTime dh) {
    _dataInstalacao = DateTime(dh.year, dh.month, dh.day);
    _horaInstalacaoCtrl.text = dh.hour.toString().padLeft(2, '0');
    _minutoInstalacaoCtrl.text = dh.minute.toString().padLeft(2, '0');
  }

  @override
  void initState() {
    super.initState();
    _pontoGeralIdAtual = (widget.pontoGeralId != null && widget.pontoGeralId!.isNotEmpty) ? widget.pontoGeralId : null;
    if (_pontoGeralIdAtual == null) _hasChanges = true;
    _definirDataHoraInstalacao(DateTime.now());
    _carregarDados();
  }

  @override
  void dispose() {
    _horaInstalacaoCtrl.dispose();
    _minutoInstalacaoCtrl.dispose();
    super.dispose();
  }

  List<MedicaoFissuraModel> get _medicoesOrdenadas {
    final lista = [..._medicoes];
    lista.sort((a, b) => (a.dataHora ?? DateTime(0)).compareTo(b.dataHora ?? DateTime(0)));
    return lista;
  }

  InstalacaoFissuraModel get _instalacaoAtual => InstalacaoFissuraModel(
        id: _instalacaoId,
        pontoGeralId: _pontoGeralIdAtual,
        dataHora: _dataHoraInstalacao,
        foto1: _urlFoto1,
        foto2: _urlFoto2,
        tipoSelo: _seloSelecionado,
        medicoes: _medicoes,
      );

  Future<void> _carregarDados() async {
    if (_pontoGeralIdAtual == null) {
      setState(() => _isInitializing = false);
      return;
    }
    try {
      final instalacao = await ref.read(monitoramentoFissuraRepositoryProvider).buscarInstalacao(_pontoGeralIdAtual!);
      if (instalacao != null) {
        _instalacaoId = instalacao.id;
        _definirDataHoraInstalacao(instalacao.dataHora ?? DateTime.now());
        _seloSelecionado = instalacao.tipoSelo;
        _urlFoto1 = instalacao.foto1;
        _urlFoto2 = instalacao.foto2;
        _medicoes = instalacao.medicoes;
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

  Future<void> _salvarInstalacao() async {
    // Trava síncrona de reentrância — o botão só fica desabilitado
    // (`onPressed: _isLoading ? null : _salvarInstalacao`) a partir do
    // PRÓXIMO rebuild/frame. Num toque duplo rápido, a segunda chamada ainda
    // acha o botão habilitado e entra aqui de novo antes do rebuild
    // acontecer. Como o repositório decide INSERT vs UPDATE em
    // `pontos_ensaios_geral` e `ponto_ensaio_monitoramento_fissura` a partir
    // de `_pontoGeralIdAtual`/`_instalacaoId` (nulos pra uma instalação
    // nova), as duas chamadas cairiam no ramo de INSERT e duplicariam as
    // linhas. Setar `_isLoading` aqui é síncrono (setState muda o campo na
    // hora, só o rebuild é adiado), então a segunda chamada já vê
    // `_isLoading == true` e sai antes de inserir de novo.
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final res = await ref.read(monitoramentoFissuraRepositoryProvider).salvarInstalacao(
            dados: _instalacaoAtual,
            projetoId: widget.projetoId,
            elementoId: widget.elementoId,
            tipoEnsaioId: widget.tipoEnsaioId,
            pontoNome: widget.pontoNome,
            foto1Nova: _foto1Local,
            foto2Nova: _foto2Local,
          );
      _pontoGeralIdAtual = res['pontoGeralId'] as String;
      _foto1Local = null;
      _foto2Local = null;
      ref.invalidate(resumoEnsaiosProvider);
      await _carregarDados();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirNovaMedicao({MedicaoFissuraModel? medicaoExistente}) async {
    if (_pontoGeralIdAtual == null || _hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve as informações da instalação primeiro.'), backgroundColor: Colors.orange));
      return;
    }
    final ordenadas = _medicoesOrdenadas.where((m) => m.id != medicaoExistente?.id).toList();
    final anterior = ordenadas.isEmpty ? null : ordenadas.last;

    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => NovaMedicaoModal(
        seloPermiteRompimento: _seloSelecionado.podeRomper,
        medicaoExistente: medicaoExistente,
        medicaoAnterior: anterior,
      ),
    );
    if (resultado == null) return;

    setState(() => _isLoading = true);
    try {
      final medidaX = resultado['medidaX'] as double;
      final medidaY = resultado['medidaY'] as double;
      final rompido = resultado['rompido'] as bool;
      final variacao = calcularVariacao(
        medicoesAnterioresOrdenadas: ordenadas,
        medidaX: medidaX,
        medidaY: medidaY,
        rompidoInformado: rompido,
      );

      final medicao = MedicaoFissuraModel(
        id: medicaoExistente?.id,
        instalacaoId: _instalacaoId,
        dataHora: resultado['dataHora'] as DateTime,
        foto: medicaoExistente?.foto,
        descricao: resultado['descricao'] as String,
        temperatura: resultado['temperatura'] as double?,
        umidade: resultado['umidade'] as double?,
        medidaX: medidaX,
        medidaY: medidaY,
        status: variacao.status,
      );

      await ref.read(monitoramentoFissuraRepositoryProvider).salvarMedicao(
            pontoGeralId: _pontoGeralIdAtual!,
            instalacaoAtual: _instalacaoAtual,
            medicao: medicao,
            fotoNova: resultado['foto'] as File?,
          );
      ref.invalidate(resumoEnsaiosProvider);
      await _carregarDados();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medição salva!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _excluirMedicao(MedicaoFissuraModel medicao) async {
    if (_pontoGeralIdAtual == null || medicao.id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir medição'),
        content: const Text('Deseja realmente excluir esta medição?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(monitoramentoFissuraRepositoryProvider)
          .deletarMedicao(pontoGeralId: _pontoGeralIdAtual!, instalacaoAtual: _instalacaoAtual, medicaoId: medicao.id!);
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
        content: const Text('Deseja realmente excluir este ponto de monitoramento e todas as suas medições?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(monitoramentoFissuraRepositoryProvider).deletarPontoCompleto(_pontoGeralIdAtual!);
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
    final medicoes = _medicoesOrdenadas;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _pontoGeralIdAtual == null
          ? null
          : MenuDrawerAppBar(
              title: 'Ponto de\nMonitoramento',
              items: [
                DiaviconMenuItem(
                  icon: Icons.show_chart,
                  label: 'Análise',
                  onTap: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (_pontoGeralIdAtual == null || _hasChanges) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange));
                      return;
                    }
                    navigator.push(MaterialPageRoute(
                      builder: (context) => AnalisePontoMonitoramentoFissuraScreen(
                        pontoGeralId: _pontoGeralIdAtual!,
                        pontoNome: widget.pontoNome,
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve as informações primeiro.'), backgroundColor: Colors.orange));
                      return;
                    }
                    navigator.push(MaterialPageRoute(
                      builder: (context) => GaleriaEnsaioScreen(
                        pontoGeralId: _pontoGeralIdAtual!,
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
                    onPressed: () {
                      Navigator.pop(context);
                      _excluirPonto();
                    },
                  ),
              ],
            ),
      appBar: CustomAppBar(
        title: 'Monitoramento de Fissuras',
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
                    _buildCardInstalacao(),
                    if (_hasChanges && permissoes.canEdit) ...[
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _salvarInstalacao,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFA726), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('Salvar instalação', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Medições', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                        if (permissoes.canEdit)
                          TextButton.icon(
                            onPressed: _isLoading ? null : () => _abrirNovaMedicao(),
                            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                            label: Text('Nova medição', style: GoogleFonts.lato(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (medicoes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('Nenhuma medição registrada ainda.', style: GoogleFonts.lato(color: Colors.grey))),
                      )
                    else
                      ...medicoes.reversed.map((m) => _buildCardMedicao(m, permissoes)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CARD DE INSTALAÇÃO (sempre editável, sem etapa separada)
  // ==========================================
  Widget _buildCardInstalacao() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instalação', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
          Text(widget.tipoElemento, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
          Text(widget.local, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCardFoto('Foto inicial 1', _foto1Local, _urlFoto1, () async {
                final f = await _escolherFoto();
                if (f != null) setState(() { _foto1Local = f; _onCampoAlterado(); });
              })),
              const SizedBox(width: 12),
              Expanded(child: _buildCardFoto('Foto inicial 2', _foto2Local, _urlFoto2, () async {
                final f = await _escolherFoto();
                if (f != null) setState(() { _foto2Local = f; _onCampoAlterado(); });
              })),
            ],
          ),
          const SizedBox(height: 16),
          Text('Data/hora da instalação', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final data = await showDatePicker(context: context, initialDate: _dataInstalacao, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (data == null) return;
                    setState(() { _dataInstalacao = data; _onCampoAlterado(); });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9E9E9E)), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Text(DateFormat('dd/MM/yyyy').format(_dataInstalacao), style: GoogleFonts.lato(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 68,
                child: TextField(
                  controller: _horaInstalacaoCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'HH',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _onCampoAlterado(),
                ),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14), child: Text(':', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold))),
              SizedBox(
                width: 68,
                child: TextField(
                  controller: _minutoInstalacaoCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'MM',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => _onCampoAlterado(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF9E9E9E)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF9F9F9)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TipoSeloFissura>(
                isExpanded: true,
                value: _seloSelecionado,
                items: TipoSeloFissura.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (val) { if (val != null) setState(() { _seloSelecionado = val; _onCampoAlterado(); }); },
              ),
            ),
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
          vazio: const Center(child: Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 28)),
          acao: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.edit_square, size: 14, color: Color(0xFF3E3E3D)),
          ),
        ),
      ],
    );
  }

  Widget _buildCardMedicao(MedicaoFissuraModel medicao, EnsaioPermissoes permissoes) {
    return InkWell(
      onTap: permissoes.canEdit ? () => _abrirNovaMedicao(medicaoExistente: medicao) : null,
      onLongPress: permissoes.canDelete ? () => _excluirMedicao(medicao) : null,
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
                image: medicao.foto != null && medicao.foto!.isNotEmpty ? DecorationImage(image: StorageNetworkImage(medicao.foto!), fit: BoxFit.cover) : null,
              ),
              child: medicao.foto == null || medicao.foto!.isEmpty ? const Icon(Icons.image_outlined, color: Colors.grey, size: 20) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        medicao.dataHora != null ? DateFormat('dd/MM/yyyy · HH:mm').format(medicao.dataHora!) : '-',
                        style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: medicao.status.cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(medicao.status.label, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: medicao.status.cor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medicao.temperatura != null ? '${medicao.temperatura!.toStringAsFixed(0)}°C · ' : ''}'
                    '${medicao.umidade != null ? '${medicao.umidade!.toStringAsFixed(0)}% UR · ' : ''}'
                    'X: ${medicao.medidaX.toStringAsFixed(1)}mm · Y: ${medicao.medidaY.toStringAsFixed(1)}mm',
                    style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D)),
                  ),
                  if (medicao.descricao.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(medicao.descricao, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade700)),
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
