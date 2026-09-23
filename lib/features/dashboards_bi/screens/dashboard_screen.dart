import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../planos/acesso_plano.dart';
import '../models/bi_data_point.dart';
import '../models/bi_filtros_model.dart';
import '../models/dashboard_card_model.dart';
import '../utils/classificadores_bi.dart';
import '../models/dashboard_modelo_model.dart';
import '../repositories/dashboard_bi_repository.dart';
import '../utils/bi_grid_packer.dart';
import '../widgets/construtor_eixos_modal.dart';
import '../widgets/bi_tema.dart';
import '../widgets/dashboard_card_view.dart';

/// Tela única de dashboard, reaproveitada nos 4 pontos de entrada
/// (projeto/estrutura/elemento/estrutura-multi-projeto) E na edição direta
/// de um modelo em "Padrões da empresa" (quando [modeloParaEditar] é
/// passado — nesse caso não existe `dashboard_instancias`, edita-se
/// `schema_json` do modelo direto, sem prévia com dados reais).
class DashboardScreen extends ConsumerStatefulWidget {
  final NivelAplicacaoBi nivel;
  final String? projetoId;
  final String? estruturaId;
  final String? elementoId;
  final String titulo;
  final bool ofereceMultiProjeto;
  final DashboardModeloModel? modeloParaEditar;

  const DashboardScreen({
    super.key,
    required this.nivel,
    this.projetoId,
    this.estruturaId,
    this.elementoId,
    required this.titulo,
    this.ofereceMultiProjeto = false,
    this.modeloParaEditar,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _repo = DashboardBiRepository();

  bool get _modoTemplate => widget.modeloParaEditar != null;

  bool _carregando = true;
  bool _salvando = false;
  List<DashboardModeloModel> _modelosDisponiveis = [];
  DashboardModeloModel? _modelo;
  DashboardInstanciaModel? _instancia;
  List<DashboardCardModel> _cards = [];
  final Set<String> _removidosIds = {};
  bool _modoEdicao = false;

  // Cópia dos cards ao entrar na personalização, para o "Descartar".
  List<DashboardCardModel>? _cardsAntesDaEdicao;
  Set<String> _removidosAntesDaEdicao = {};

  // Nível efetivamente carregado — pode diferir de widget.nivel quando
  // ofereceMultiProjeto permite escolher um modelo "estrutura_multi_projeto"
  // no mesmo ponto de entrada da estrutura. Todo id enviado ao banco (ou
  // usado pra buscar dados) é sempre derivado DESTE nível via
  // `_idsParaNivel`, nunca dos ids brutos do widget — uma estrutura com n
  // projetos, por exemplo, não pode carregar um projeto_id específico.
  late NivelAplicacaoBi _nivelAtivo = widget.nivel;

  BiFiltrosSelecionados _filtros = const BiFiltrosSelecionados();
  BiOpcoesFiltro _opcoesFiltro = const BiOpcoesFiltro();

  final Map<String, List<BiDataPoint>> _dadosCache = {};
  final Map<String, List<BiDataPoint>> _dadosCacheSecundarios = {};
  final Map<String, List<Map<String, String?>>> _galeriaCache = {};
  // Cards de varias series: card.id -> (serie/coluna/entrada -> pontos).
  final Map<String, Map<String, List<BiDataPoint>>> _seriesCache = {};
  final Set<String> _carregandoIds = {};
  final Set<String> _semDadoIds = {};

  @override
  void initState() {
    super.initState();
    _modoEdicao = _modoTemplate;
    _carregarInicial();
  }

  ({String? projetoId, String? estruturaId, String? elementoId}) _idsParaNivel(NivelAplicacaoBi nivel) {
    switch (nivel) {
      case NivelAplicacaoBi.projeto:
        return (projetoId: widget.projetoId, estruturaId: null, elementoId: null);
      case NivelAplicacaoBi.estruturaMultiProjeto:
        return (projetoId: null, estruturaId: widget.estruturaId, elementoId: null);
      case NivelAplicacaoBi.estruturaNoProjeto:
        return (projetoId: widget.projetoId, estruturaId: widget.estruturaId, elementoId: null);
      case NivelAplicacaoBi.elementoNoProjeto:
        return (projetoId: widget.projetoId, estruturaId: widget.estruturaId, elementoId: widget.elementoId);
    }
  }

  BiContexto _contexto() {
    final empresaId = ref.read(currentUserProvider)?.empresaId ?? widget.modeloParaEditar?.empresaId ?? '';
    final ids = _idsParaNivel(_nivelAtivo);
    return BiContexto(
      empresaId: empresaId,
      projetoId: ids.projetoId,
      estruturaId: ids.estruturaId,
      elementoId: ids.elementoId,
      filtroLocal: _filtros.locais,
      filtroTipoElemento: _filtros.tiposElemento,
      filtroSistema: _filtros.sistemas,
      filtroProjeto: _filtros.projetos,
      filtroConjuntoEstrutural: _filtros.conjuntosEstruturais,
      filtroEstrutura: _filtros.estruturas,
    );
  }

  Future<void> _carregarOpcoesFiltro() async {
    final ids = _idsParaNivel(_nivelAtivo);
    final opcoes = await _repo.buscarOpcoesFiltro(_nivelAtivo, projetoId: ids.projetoId, estruturaId: ids.estruturaId);
    if (!mounted) return;
    setState(() => _opcoesFiltro = opcoes);
  }

  void _aplicarFiltros(BiFiltrosSelecionados novo) {
    setState(() => _filtros = novo);
    _carregarDadosDeTodosOsCards();
  }

  Future<void> _carregarInicial() async {
    setState(() => _carregando = true);

    if (_modoTemplate) {
      _modelo = widget.modeloParaEditar;
      _cards = List.from(_modelo!.cards);
      setState(() => _carregando = false);
      return;
    }

    final empresaId = ref.read(currentUserProvider)?.empresaId;
    if (empresaId == null) {
      setState(() => _carregando = false);
      return;
    }

    final niveis = widget.ofereceMultiProjeto ? [widget.nivel, NivelAplicacaoBi.estruturaMultiProjeto] : [widget.nivel];

    for (final nivel in niveis) {
      final ids = _idsParaNivel(nivel);
      final instancia = await _repo.buscarInstancia(nivel: nivel, projetoId: ids.projetoId, estruturaId: ids.estruturaId, elementoId: ids.elementoId);
      if (instancia == null) continue;
      final modelo = await _repo.buscarModelo(instancia.modeloId);
      if (modelo == null) continue;
      _instancia = instancia;
      _modelo = modelo;
      _nivelAtivo = nivel;
      _cards = mesclarOverrides(modelo.cards, instancia.overridesJson)..sort((a, b) => a.gridY != b.gridY ? a.gridY.compareTo(b.gridY) : a.gridX.compareTo(b.gridX));
      setState(() => _carregando = false);
      _carregarOpcoesFiltro();
      _carregarDadosDeTodosOsCards();
      return;
    }

    await _carregarModelosDisponiveis(empresaId, niveis);
  }

  Future<void> _carregarModelosDisponiveis(String empresaId, List<NivelAplicacaoBi> niveis) async {
    final modelos = <DashboardModeloModel>[];
    for (final nivel in niveis) {
      modelos.addAll(await _repo.listarModelos(empresaId: empresaId, nivel: nivel));
    }
    setState(() {
      _modelosDisponiveis = modelos;
      _carregando = false;
    });
  }

  Future<void> _excluirDashboard() async {
    final instancia = _instancia;
    if (instancia == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir dashboard?'),
        content: const Text('A visualização atual (modelo escolhido e customizações) será apagada. Você vai poder escolher outro modelo em seguida.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _carregando = true);
    try {
      await _repo.excluirInstancia(instancia.id, instancia.nivelAplicacao);
      final empresaId = ref.read(currentUserProvider)?.empresaId ?? '';
      final niveis = widget.ofereceMultiProjeto ? [widget.nivel, NivelAplicacaoBi.estruturaMultiProjeto] : [widget.nivel];
      _instancia = null;
      _modelo = null;
      _cards = [];
      _removidosIds.clear();
      _dadosCache.clear();
      _dadosCacheSecundarios.clear();
      _galeriaCache.clear();
      _seriesCache.clear();
      _semDadoIds.clear();
      _modoEdicao = false;
      _filtros = const BiFiltrosSelecionados();
      _opcoesFiltro = const BiOpcoesFiltro();
      await _carregarModelosDisponiveis(empresaId, niveis);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red));
      setState(() => _carregando = false);
    }
  }

  Future<void> _escolherModelo(DashboardModeloModel modelo) async {
    setState(() => _carregando = true);
    final empresaId = ref.read(currentUserProvider)?.empresaId ?? '';
    final ids = _idsParaNivel(modelo.nivelAplicacao);
    final novaInstancia = DashboardInstanciaModel(
      id: '',
      criadoEm: DateTime.now(),
      modeloId: modelo.id,
      projetoId: ids.projetoId,
      estruturaId: ids.estruturaId,
      elementoId: ids.elementoId,
      empresaId: empresaId,
      nivelAplicacao: modelo.nivelAplicacao,
    );
    final id = await _repo.criarInstancia(novaInstancia);
    _instancia = DashboardInstanciaModel(
      id: id,
      criadoEm: novaInstancia.criadoEm,
      modeloId: modelo.id,
      projetoId: ids.projetoId,
      estruturaId: ids.estruturaId,
      elementoId: ids.elementoId,
      empresaId: empresaId,
      nivelAplicacao: modelo.nivelAplicacao,
    );
    _modelo = modelo;
    _nivelAtivo = modelo.nivelAplicacao;
    _cards = List.from(modelo.cards)..sort((a, b) => a.gridY != b.gridY ? a.gridY.compareTo(b.gridY) : a.gridX.compareTo(b.gridX));
    setState(() => _carregando = false);
    _carregarOpcoesFiltro();
    _carregarDadosDeTodosOsCards();
  }

  Future<void> _carregarDadosDeTodosOsCards() async {
    if (_modoTemplate) return;
    for (final card in _cards) {
      _carregarDadosDoCard(card);
    }
  }

  Future<void> _carregarDadosDoCard(DashboardCardModel card) async {
    if (card.tipo == TipoCardBi.texto || card.tipo == TipoCardBi.espaco) return;
    setState(() => _carregandoIds.add(card.id));
    try {
      final ctx = _contexto();
      if (card.tipo == TipoCardBi.galeria) {
        final fotos = await _repo.buscarGaleriaCard(card.galeriaFonteChave, ctx);
        if (!mounted) return;
        setState(() {
          _galeriaCache[card.id] = fotos;
          if (fotos.isEmpty) _semDadoIds.add(card.id); else _semDadoIds.remove(card.id);
        });
      } else if (card.usaSeries) {
        final series = await _repo.buscarSeriesCard(card, ctx);
        if (!mounted) return;
        setState(() {
          _seriesCache[card.id] = series;
          final vazio = series.values.every((l) => l.isEmpty);
          if (vazio) _semDadoIds.add(card.id); else _semDadoIds.remove(card.id);
        });
      } else {
        final pontos = await _repo.buscarDadosCard(card, ctx);
        final pontosSecundarios = card.campoY != null ? await _repo.buscarDadosCardSecundarios(card, ctx) : const <BiDataPoint>[];
        if (!mounted) return;
        setState(() {
          _dadosCache[card.id] = pontos;
          _dadosCacheSecundarios[card.id] = pontosSecundarios;
          if (pontos.isEmpty) _semDadoIds.add(card.id); else _semDadoIds.remove(card.id);
        });
      }
    } finally {
      if (mounted) setState(() => _carregandoIds.remove(card.id));
    }
  }

  void _atualizarCards(List<DashboardCardModel> novos) {
    setState(() => _cards = reempacotarGrid(novos));
  }

  Future<void> _adicionarCard() async {
    final novo = await abrirConstrutorEixosModal(context, nivel: _nivelAtivo);
    if (novo == null) return;
    _atualizarCards([..._cards, novo]);
    _carregarDadosDoCard(novo);
  }

  void _excluirCard(DashboardCardModel card) {
    _removidosIds.add(card.id);
    _atualizarCards(_cards.where((c) => c.id != card.id).toList());
  }

  void _alternarVisibilidade(DashboardCardModel card) {
    _atualizarCards(_cards.map((c) => c.id == card.id ? c.copyWith(visivel: !c.visivel) : c).toList());
  }

  void _redimensionarLargura(DashboardCardModel card, int delta) {
    final novaLargura = (card.largura + delta).clamp(1, 7);
    _atualizarCards(_cards.map((c) => c.id == card.id ? c.copyWith(largura: novaLargura) : c).toList());
  }

  void _redimensionarAltura(DashboardCardModel card, int delta) {
    final novaAltura = (card.altura + delta).clamp(1, alturaMaximaCardBi);
    _atualizarCards(_cards.map((c) => c.id == card.id ? c.copyWith(altura: novaAltura) : c).toList());
  }

  Future<void> _editarDadosCard(DashboardCardModel card) async {
    final editado = await abrirConstrutorEixosModal(context, nivel: _nivelAtivo, cardExistente: card);
    if (editado == null) return;
    _atualizarCards(_cards.map((c) => c.id == card.id ? editado : c).toList());
    _carregarDadosDoCard(editado);
  }

  Future<void> _abrirEditarTamanho(DashboardCardModel card) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final atual = _cards.firstWhere((c) => c.id == card.id, orElse: () => card);
          return AlertDialog(
            title: const Text('Tamanho do card'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stepperLinha(
                  label: 'Largura',
                  valor: atual.largura,
                  onDiminuir: () => setDialogState(() => _redimensionarLargura(atual, -1)),
                  onAumentar: () => setDialogState(() => _redimensionarLargura(atual, 1)),
                ),
                const SizedBox(height: 12),
                _stepperLinha(
                  label: 'Altura',
                  valor: atual.altura,
                  onDiminuir: () => setDialogState(() => _redimensionarAltura(atual, -1)),
                  onAumentar: () => setDialogState(() => _redimensionarAltura(atual, 1)),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Concluído')),
            ],
          );
        },
      ),
    );
  }

  Widget _stepperLinha({required String label, required int valor, required VoidCallback onDiminuir, required VoidCallback onAumentar}) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: onDiminuir),
        SizedBox(width: 24, child: Text('$valor', textAlign: TextAlign.center)),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onAumentar),
      ],
    );
  }

  Future<void> _abrirMenuCard(DashboardCardModel card) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(card.visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              title: Text(card.visivel ? 'Ocultar' : 'Mostrar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _alternarVisibilidade(card);
              },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_outlined),
              title: const Text('Editar largura e altura'),
              onTap: () {
                Navigator.pop(sheetContext);
                _abrirEditarTamanho(card);
              },
            ),
            if (card.tipo != TipoCardBi.espaco)
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Editar dados'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _editarDadosCard(card);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                _excluirCard(card);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirReordenar() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ReordenarCardsSheet(
        cards: _cards,
        onReordenado: _atualizarCards,
      ),
    );
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      if (_modoTemplate) {
        final base = _modelo!;
        final atualizado = DashboardModeloModel(
          id: base.id,
          criadoEm: base.criadoEm,
          empresaId: base.empresaId,
          criadoPor: base.criadoPor,
          nivelAplicacao: base.nivelAplicacao,
          nome: base.nome,
          isPadrao: base.isPadrao,
          modeloOrigemId: base.modeloOrigemId,
          cards: _cards,
        );
        await _repo.atualizarModelo(base.id, atualizado);
      } else if (_instancia != null) {
        final overrides = {
          ...cardsParaSchemaJson(_cards),
          '_removidos': _removidosIds.toList(),
        };
        await _repo.salvarOverrides(_instancia!.id, overrides, _instancia!.nivelAplicacao);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visualização salva.'), backgroundColor: Colors.green));
      setState(() => _modoEdicao = _modoTemplate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dashboard é recurso de plano (coluna `dashboard` em `planos`).
    return GuardaModuloPlano(
      modulo: ModuloPlano.dashboard,
      child: Builder(builder: _buildConteudo),
    );
  }

  Widget _buildConteudo(BuildContext context) {
    return Scaffold(
      backgroundColor: kBiFundo,
      endDrawer: _buildEndDrawer(),
      appBar: CustomAppBar(
        title: 'Dashboard',
        showBackButton: true,
        showMenuButton: !_modoTemplate && _modelo != null,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_modoTemplate ? 'Modelo de dashboard' : 'Dashboard', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            Text(
              _modoTemplate ? (_modelo?.nome ?? widget.titulo) : widget.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _modelo == null
              ? _buildSeletorModelo()
              : _buildGridDashboard(),
    );
  }

  /// Largura máxima do conteúdo: em monitor largo o grid de 7 colunas virava
  /// quadrados enormes.
  static const _larguraMaxima = 1280.0;

  Widget _centralizado(Widget child, {EdgeInsets padding = EdgeInsets.zero}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _larguraMaxima),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  void _entrarEdicao() {
    _cardsAntesDaEdicao = List.from(_cards);
    _removidosAntesDaEdicao = {..._removidosIds};
    setState(() => _modoEdicao = true);
  }

  /// Sai da edição sem salvar: volta os cards como estavam. Antes o botão só
  /// trocava o modo e as mudanças ficavam na tela sem estarem salvas.
  void _descartarEdicao() {
    final antes = _cardsAntesDaEdicao;
    setState(() {
      if (antes != null) _cards = antes;
      _removidosIds
        ..clear()
        ..addAll(_removidosAntesDaEdicao);
      _modoEdicao = false;
      _cardsAntesDaEdicao = null;
    });
  }

  Widget _buildSeletorModelo() {
    if (_modelosDisponiveis.isEmpty) {
      return _centralizado(
        Container(
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBiBorda)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 44, color: AppColors.primary),
              SizedBox(height: 12),
              Text('Nenhum modelo de dashboard para este nível', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kBiTinta)),
              SizedBox(height: 6),
              Text(
                'Um administrador da empresa pode criar um em Painel › Padrões da empresa › Modelos de dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kBiSuave, height: 1.4),
              ),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
      );
    }
    final usuarioEmpresa = ref.read(currentUserProvider)?.empresaId;
    return SingleChildScrollView(
      child: _centralizado(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Escolha um modelo de dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kBiTinta)),
            const SizedBox(height: 4),
            const Text(
              'O modelo define os gráficos. Depois dá para personalizar este dashboard sem alterar o modelo.',
              style: TextStyle(fontSize: 13, color: kBiSuave, height: 1.4),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                const espaco = 12.0;
                final colunas = ((c.maxWidth + espaco) / (340 + espaco)).floor().clamp(1, 3);
                final largura = (c.maxWidth - espaco * (colunas - 1)) / colunas;
                return Wrap(
                  spacing: espaco,
                  runSpacing: espaco,
                  children: [
                    for (final modelo in _modelosDisponiveis)
                      SizedBox(
                        width: largura,
                        child: _CartaoModelo(
                          modelo: modelo,
                          selo: modelo.empresaId == DIAVICON_EMPRESA_ID && modelo.empresaId != usuarioEmpresa
                              ? 'Padrão DIAVICON'
                              : (modelo.isPadrao ? 'Padrão da empresa' : null),
                          aoEscolher: () => _escolherModelo(modelo),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      ),
    );
  }

  Widget _buildCabecalho() {
    // `compacto` = tela estreita: os botões viram ícones e os filtros correm
    // numa linha só, para o cabeçalho não comer meia tela.
    List<Widget> acoesDo({required bool compacto}) => [
          if (!_modoEdicao) ...[
            if (!_modoTemplate)
              _BotaoBi(
                rotulo: 'Atualizar',
                icone: Icons.refresh_rounded,
                aoTocar: _carregarDadosDeTodosOsCards,
                somenteIcone: compacto,
              ),
            _BotaoBi(
              rotulo: 'Personalizar',
              icone: Icons.tune_rounded,
              aoTocar: _entrarEdicao,
              somenteIcone: compacto,
            ),
          ] else ...[
            _BotaoBi(
              rotulo: 'Adicionar card',
              icone: Icons.add_chart_rounded,
              aoTocar: _adicionarCard,
              somenteIcone: compacto,
            ),
            _BotaoBi(
              rotulo: 'Reordenar',
              icone: Icons.reorder_rounded,
              aoTocar: _abrirReordenar,
              somenteIcone: compacto,
            ),
            if (!_modoTemplate)
              _BotaoBi(
                rotulo: 'Descartar',
                icone: Icons.undo_rounded,
                aoTocar: _salvando ? null : _descartarEdicao,
                somenteIcone: compacto,
              ),
            _BotaoBi(
              rotulo: _salvando ? 'Salvando...' : 'Salvar',
              icone: Icons.check_rounded,
              primario: true,
              aoTocar: _salvando ? null : _salvar,
              somenteIcone: compacto,
            ),
          ],
        ];

    final nivel = _modelo?.nivelAplicacao.rotulo;
    Widget tituloDo({required bool compacto}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _modoTemplate ? 'Editando modelo' : widget.titulo,
              maxLines: compacto ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compacto ? 17 : 20,
                fontWeight: FontWeight.w800,
                color: kBiTinta,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              [if (_modelo != null) 'Modelo: ${_modelo!.nome}', ?nivel].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: kBiSuave),
            ),
          ],
        );

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: kBiBorda))),
      child: _centralizado(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final compacto = c.maxWidth < 640;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: tituloDo(compacto: compacto)),
                    const SizedBox(width: 10),
                    Wrap(
                      spacing: compacto ? 6 : 8,
                      runSpacing: 8,
                      children: acoesDo(compacto: compacto),
                    ),
                  ],
                );
              },
            ),
            if (!_modoTemplate && !_opcoesFiltro.semFiltros) ...[
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, c) => _buildBarraFiltros(compacto: c.maxWidth < 640),
              ),
            ],
            if (_modoEdicao) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFFF6EA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF7D7AE))),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFA85A00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _modoTemplate
                            ? 'Use ⋮ em cada card para ocultar, redimensionar, editar os dados ou excluir. Salve para gravar o modelo.'
                            : 'Personalizando este dashboard: use ⋮ em cada card para ocultar, redimensionar, editar ou excluir. O modelo da empresa não muda.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B4A1F), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      ),
    );
  }

  Widget _buildGridDashboard() {
    // Card de texto vazio só aparece na edição: na leitura era um quadro em branco.
    bool textoVazio(DashboardCardModel c) => c.tipo == TipoCardBi.texto && (c.textoConteudo ?? '').trim().isEmpty;
    final visiveis = _cards.where((c) => _modoEdicao || (c.visivel && !_semDadoIds.contains(c.id) && !textoVazio(c))).toList();
    final ocultosSemDado = _modoEdicao ? 0 : _cards.where((c) => c.visivel && _semDadoIds.contains(c.id)).length;
    return Column(
      children: [
        _buildCabecalho(),
        Expanded(
          child: visiveis.isEmpty
              ? SingleChildScrollView(
                  child: _centralizado(
                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBiBorda)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insights_outlined, size: 40, color: AppColors.primary),
                          const SizedBox(height: 10),
                          Text(
                            _modoEdicao ? 'Nenhum card neste dashboard' : 'Ainda não há dados para os cards deste dashboard',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBiTinta),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _modoEdicao
                                ? 'Adicione gráficos, tabelas, classificações ou galerias.'
                                : 'Os gráficos aparecem conforme os ensaios forem registrados. Os filtros também podem estar escondendo os dados.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: kBiSuave, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          if (_modoEdicao)
                            _BotaoBi(rotulo: 'Adicionar card', icone: Icons.add_chart_rounded, primario: true, aoTocar: _adicionarCard)
                          else if (_filtros.algumFiltroAtivo)
                            _BotaoBi(rotulo: 'Limpar filtros', icone: Icons.filter_alt_off_outlined, aoTocar: () => _aplicarFiltros(const BiFiltrosSelecionados())),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _carregarDadosDeTodosOsCards,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: _centralizado(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StaggeredGrid.count(
                            crossAxisCount: 7,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            children: visiveis.map((card) {
                              return StaggeredGridTile.count(
                                crossAxisCellCount: card.largura,
                                mainAxisCellCount: card.altura,
                                child: Opacity(
                                  opacity: _modoEdicao && !card.visivel ? 0.4 : 1,
                                  child: DashboardCardView(
                                    card: card,
                                    pontos: _dadosCache[card.id],
                                    pontosSecundarios: _dadosCacheSecundarios[card.id],
                                    series: _seriesCache[card.id],
                                    fotosGaleria: _galeriaCache[card.id],
                                    carregando: _carregandoIds.contains(card.id),
                                    modoEdicao: _modoEdicao,
                                    onAbrirMenu: () => _abrirMenuCard(card),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          // Transparência: cards sem dado somem no modo leitura;
                          // avisa quantos, para não parecer que o dashboard perdeu cards.
                          if (ocultosSemDado > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.visibility_off_outlined, size: 14, color: kBiSuave),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      ocultosSemDado == 1
                                          ? '1 card sem dados está oculto'
                                          : '$ocultosSemDado cards sem dados estão ocultos',
                                      style: const TextStyle(fontSize: 12, color: kBiSuave),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 60),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget? _buildEndDrawer() {
    if (_modelo == null || _modoTemplate) return null;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('Dashboard', style: TextStyle(color: kBiSuave, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
            if (_instancia != null)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFB3261E)),
                title: const Text('Trocar de modelo', style: TextStyle(color: Color(0xFFB3261E), fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: const Text('Apaga as personalizações deste dashboard', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(context).pop();
                  _excluirDashboard();
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Filtros como "pílulas" sempre à vista (antes ficavam numa sanfona
  /// fechada, e só se sabia que havia filtro ativo abrindo).
  Widget _buildBarraFiltros({bool compacto = false}) {
    final itens = <Widget>[
      if (_opcoesFiltro.projetos.isNotEmpty)
        _filtroMultiplo('Projeto', _opcoesFiltro.projetos, _filtros.projetos, (v) => _aplicarFiltros(_filtros.copyWith(projetos: v))),
      if (_opcoesFiltro.conjuntosEstruturais.isNotEmpty)
        _filtroMultiplo('Conjunto', _opcoesFiltro.conjuntosEstruturais, _filtros.conjuntosEstruturais, (v) => _aplicarFiltros(_filtros.copyWith(conjuntosEstruturais: v))),
      if (_opcoesFiltro.estruturas.isNotEmpty)
        _filtroMultiplo('Estrutura', _opcoesFiltro.estruturas, _filtros.estruturas, (v) => _aplicarFiltros(_filtros.copyWith(estruturas: v))),
      if (_opcoesFiltro.locais.isNotEmpty)
        _filtroMultiplo('Local', _opcoesFiltro.locais.map((l) => BiOpcaoFiltro(l, l)).toList(), _filtros.locais, (v) => _aplicarFiltros(_filtros.copyWith(locais: v))),
      if (_opcoesFiltro.sistemas.isNotEmpty)
        _filtroMultiplo('Sistema', _opcoesFiltro.sistemas, _filtros.sistemas, (v) => _aplicarFiltros(_filtros.copyWith(sistemas: v))),
      if (_opcoesFiltro.tiposElemento.isNotEmpty)
        _filtroMultiplo('Tipo de elemento', _opcoesFiltro.tiposElemento.map((t) => BiOpcaoFiltro(t, t)).toList(), _filtros.tiposElemento, (v) => _aplicarFiltros(_filtros.copyWith(tiposElemento: v))),
    ];
    final limpar = _filtros.algumFiltroAtivo
        ? TextButton.icon(
            onPressed: () => _aplicarFiltros(const BiFiltrosSelecionados()),
            icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
            label: Text(compacto ? 'Limpar' : 'Limpar filtros'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFA85A00),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          )
        : null;

    // Na tela estreita os filtros correm de lado, sempre numa linha só.
    if (compacto) {
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: itens.length + (limpar == null ? 1 : 2),
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.only(right: 2, top: 9),
                child: Icon(Icons.filter_list_rounded, size: 18, color: kBiSuave),
              );
            }
            final indice = i - 1;
            if (indice < itens.length) return Center(child: itens[indice]);
            return Center(child: limpar!);
          },
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, right: 8),
          child: Icon(Icons.filter_list_rounded, size: 18, color: kBiSuave),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...itens,
              ?limpar,
            ],
          ),
        ),
      ],
    );
  }

  Widget _filtroMultiplo(String titulo, List<BiOpcaoFiltro> opcoes, List<String> selecionados, ValueChanged<List<String>> onChanged) {
    final ativo = selecionados.isNotEmpty;
    String rotulo;
    if (!ativo) {
      rotulo = 'Todos';
    } else if (selecionados.length == 1) {
      rotulo = opcoes.firstWhere((o) => o.id == selecionados.first, orElse: () => BiOpcaoFiltro(selecionados.first, selecionados.first)).nome;
    } else {
      rotulo = '${selecionados.length} selecionados';
    }
    return Material(
      color: ativo ? const Color(0xFFFFF3E0) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final resultado = await _abrirSeletorMultiplo(titulo, opcoes, selecionados);
          if (resultado != null) onChanged(resultado);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ativo ? AppColors.primary : kBiBorda),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$titulo: ', style: const TextStyle(fontSize: 12, color: kBiSuave)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ativo ? const Color(0xFFA85A00) : kBiTinta),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more_rounded, size: 16, color: ativo ? const Color(0xFFA85A00) : kBiSuave),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>?> _abrirSeletorMultiplo(String titulo, List<BiOpcaoFiltro> opcoes, List<String> selecionadosIniciais) {
    final selecionados = {...selecionadosIniciais};
    return showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.6, maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Text(titulo, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: opcoes.map((o) {
                          return CheckboxListTile(
                            value: selecionados.contains(o.id),
                            title: Text(o.nome, style: GoogleFonts.lato(fontSize: 14)),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setDialogState(() {
                              if (v == true) {
                                selecionados.add(o.id);
                              } else {
                                selecionados.remove(o.id);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () => Navigator.of(dialogContext).pop(selecionados.toList()),
                              child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReordenarCardsSheet extends StatefulWidget {
  final List<DashboardCardModel> cards;
  final ValueChanged<List<DashboardCardModel>> onReordenado;
  const _ReordenarCardsSheet({required this.cards, required this.onReordenado});

  @override
  State<_ReordenarCardsSheet> createState() => _ReordenarCardsSheetState();
}

class _ReordenarCardsSheetState extends State<_ReordenarCardsSheet> {
  late List<DashboardCardModel> _lista;

  @override
  void initState() {
    super.initState();
    _lista = List.from(widget.cards);
  }

  String _rotulo(DashboardCardModel c) {
    switch (c.tipo) {
      case TipoCardBi.texto:
        final texto = c.textoConteudo ?? '';
        return 'Texto: ${texto.length > 20 ? '${texto.substring(0, 20)}...' : texto}';
      case TipoCardBi.galeria:
        return 'Galeria';
      case TipoCardBi.espaco:
        return 'Espaço';
      case TipoCardBi.grafico:
        return c.tipoGrafico?.rotulo ?? 'Gráfico';
      case TipoCardBi.badge:
        return 'Badge: ${buscarClassificadorBi(c.classificacaoId)?.rotulo ?? '-'}';
      case TipoCardBi.tabela:
        return 'Tabela (${c.colunas.length} colunas)';
      case TipoCardBi.monteCarlo:
        return 'Monte Carlo: ${c.monteCarlo?.analise.rotulo ?? '-'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Reordenar cards', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _lista.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _lista.removeAt(oldIndex);
                  _lista.insert(newIndex, item);
                });
                widget.onReordenado(_lista);
              },
              itemBuilder: (context, i) {
                final c = _lista[i];
                return ListTile(
                  key: ValueKey(c.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(_rotulo(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${c.largura}x${c.altura}', style: const TextStyle(color: Colors.grey)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _BotaoBi extends StatelessWidget {
  final String rotulo;
  final IconData icone;
  final VoidCallback? aoTocar;
  final bool primario;

  /// Na tela estreita o botão vira só o ícone: o cabeçalho inteiro cabe numa
  /// linha, em vez de empurrar os gráficos para baixo.
  final bool somenteIcone;

  const _BotaoBi({
    required this.rotulo,
    required this.icone,
    this.aoTocar,
    this.primario = false,
    this.somenteIcone = false,
  });

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 11);

    if (somenteIcone) {
      return Tooltip(
        message: rotulo,
        child: SizedBox(
          width: 40,
          height: 40,
          child: primario
              ? FilledButton(
                  onPressed: aoTocar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: kBiTinta,
                    shape: forma,
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(icone, size: 20),
                )
              : OutlinedButton(
                  onPressed: aoTocar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBiTinta,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kBiBorda),
                    shape: forma,
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(icone, size: 20),
                ),
        ),
      );
    }

    if (primario) {
      return FilledButton.icon(
        onPressed: aoTocar,
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: kBiTinta, shape: forma, padding: pad),
        icon: Icon(icone, size: 18),
        label: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w800)),
      );
    }
    return OutlinedButton.icon(
      onPressed: aoTocar,
      style: OutlinedButton.styleFrom(
        foregroundColor: kBiTinta,
        backgroundColor: Colors.white,
        side: const BorderSide(color: kBiBorda),
        shape: forma,
        padding: pad,
      ),
      icon: Icon(icone, size: 18),
      label: Text(rotulo, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Modelo na tela de escolha: o que ele tem (quantos cards e de que tipo)
/// ajuda a escolher sem precisar abrir cada um.
class _CartaoModelo extends StatelessWidget {
  final DashboardModeloModel modelo;
  final String? selo;
  final VoidCallback aoEscolher;

  const _CartaoModelo({required this.modelo, required this.selo, required this.aoEscolher});

  @override
  Widget build(BuildContext context) {
    final cards = modelo.cards.where((c) => c.tipo != TipoCardBi.espaco).toList();
    final graficos = cards.where((c) => c.tipo == TipoCardBi.grafico || c.tipo == TipoCardBi.monteCarlo).length;
    final outros = cards.length - graficos;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: aoEscolher,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBiBorda)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.dashboard_customize_outlined, color: Color(0xFFA85A00), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(modelo.nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kBiTinta)),
                        Text(modelo.nivelAplicacao.rotulo, style: const TextStyle(fontSize: 12, color: kBiSuave)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (selo != null) _Etiqueta(texto: selo!, destaque: true),
                  _Etiqueta(texto: '$graficos ${graficos == 1 ? 'gráfico' : 'gráficos'}'),
                  if (outros > 0) _Etiqueta(texto: '$outros ${outros == 1 ? 'outro card' : 'outros cards'}'),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: aoEscolher,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Usar este modelo', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFA85A00)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool destaque;

  const _Etiqueta({required this.texto, this.destaque = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: destaque ? const Color(0xFFFFF3E0) : const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: destaque ? const Color(0xFFA85A00) : kBiTexto),
      ),
    );
  }
}
