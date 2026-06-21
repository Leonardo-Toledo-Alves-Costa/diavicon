import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
import 'package:diavicon/features/elementos/widgets/marcacao_planta_popup.dart';
import 'package:diavicon/features/elementos/widgets/nova_opcao_modal.dart';
import 'package:diavicon/features/elementos/widgets/novo_local_widget.dart';
import 'package:diavicon/features/elementos/widgets/selecionar_planta_popup.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/widgets/right_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Opcoes padrao iniciais para o campo "Tipo do Elemento".
const List<String> _defaultTipoElementoOptions = <String>[
  'Pilar',
  'Viga',
  'Laje',
];

/// Opcoes padrao iniciais para o campo "Tipologia Estrutural".
const List<String> _defaultTipologiaOptions = <String>[
  'Concreto armado',
  'Metalica',
  'Mista',
];

/// Opcoes padrao iniciais para o campo "Local do Elemento".
const List<String> _defaultLocalOptions = <String>[
  'Interno',
  'Externo',
  'Cobertura',
];

/// Opcoes padrao iniciais para o campo "Revestimento".
const List<String> _defaultRevestimentoOptions = <String>[
  'Pintura',
  'Argamassa',
  'Ceramica',
];

/// Tela de criacao de um novo elemento estrutural.
///
/// Esta tela recebe dados iniciais, carrega opcoes dinamicas quando disponiveis,
/// permite adicionar novos itens aos dropdowns e envia o rascunho final no
/// callback de submissao.
class NovoElemEstruturalScreen extends ConsumerStatefulWidget {
  /// Cria a tela com valores iniciais e callbacks opcionais para integracao.
  const NovoElemEstruturalScreen({
    super.key,
    this.estruturaId,
    this.initialNome = 'ABC Corp.',
    this.initialTipoElemento,
    this.initialTipologiaEstrutural,
    this.initialLocalElemento,
    this.initialRevestimento,
    this.initialTipoElementoOptions = _defaultTipoElementoOptions,
    this.initialTipologiaOptions = _defaultTipologiaOptions,
    this.initialLocalOptions = _defaultLocalOptions,
    this.initialRevestimentoOptions = _defaultRevestimentoOptions,
    this.onLoadFormData,
    this.onAddOption,
    this.onSubmit,
    this.onPlanPressed,
    this.onAddMarcacaoPressed,
    this.onAvatarEditPressed,
    this.onOpenInformacoes,
    this.onOpenRelatorios,
  });

  /// Estrutura à qual o novo elemento será vinculado.
  ///
  /// Necessário quando [onSubmit] não é informado: nesse caso a tela salva
  /// o elemento diretamente via [elementoRepositoryProvider].
  final String? estruturaId;
  final String initialNome;
  final String? initialTipoElemento;
  final String? initialTipologiaEstrutural;
  final String? initialLocalElemento;
  final String? initialRevestimento;
  final List<String> initialTipoElementoOptions;
  final List<String> initialTipologiaOptions;
  final List<String> initialLocalOptions;
  final List<String> initialRevestimentoOptions;
  final Future<NovoElemEstruturalFormData> Function()? onLoadFormData;
  final Future<String?> Function(EstruturalDropdownField field)? onAddOption;
  final Future<void> Function(NovoElemEstruturalDraft draft)? onSubmit;
  final VoidCallback? onPlanPressed;
  final VoidCallback? onAddMarcacaoPressed;
  final VoidCallback? onAvatarEditPressed;
  final VoidCallback? onOpenInformacoes;
  final VoidCallback? onOpenRelatorios;

  /// Cria o estado mutavel da tela.
  @override
  ConsumerState<NovoElemEstruturalScreen> createState() =>
      _NovoElemEstruturalScreenState();
}

/// Estado interno da tela de novo elemento estrutural.
///
/// Mantem os controles de formulario, as selecoes atuais e as listas mutaveis
/// usadas pelos dropdowns.
class _NovoElemEstruturalScreenState
    extends ConsumerState<NovoElemEstruturalScreen> {
  final GlobalKey<RightMenuBarState> _rightMenuKey =
      GlobalKey<RightMenuBarState>();
  late final TextEditingController _nomeController;

  String? _tipoElemento;
  String? _tipologiaEstrutural;
  String? _localElemento;
  String? _revestimento;

  late List<String> _tipoElementoOptions;
  late List<String> _tipologiaOptions;
  late List<String> _localOptions;
  late List<String> _revestimentoOptions;

  bool _isLoadingFormData = false;
  bool _isSubmitting = false;
  EstruturalDropdownField? _fieldBeingAdded;

  /// Marcação posicionada na planta (null enquanto não houver marcação).
  MarcacaoPlanta? _marcacaoPlanta;

  /// Inicializa os valores do formulario, copia as listas padrao e tenta
  /// carregar dados remotos adicionais, se o callback existir.
  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.initialNome);
    _tipoElemento = widget.initialTipoElemento;
    _tipologiaEstrutural = widget.initialTipologiaEstrutural;
    _localElemento = widget.initialLocalElemento;
    _revestimento = widget.initialRevestimento;
    _tipoElementoOptions = List<String>.from(widget.initialTipoElementoOptions);
    _tipologiaOptions = List<String>.from(widget.initialTipologiaOptions);
    _localOptions = List<String>.from(widget.initialLocalOptions);
    _revestimentoOptions = List<String>.from(widget.initialRevestimentoOptions);
    _sanitizeSelections();
    _loadFormData();
  }

  /// Libera o controller do campo de nome para evitar vazamento de memoria.
  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  /// Carrega dados iniciais do formulario por meio do callback opcional.
  ///
  /// Quando a resposta chega, atualiza o texto, as listas de dropdown e as
  /// selecoes validas, ignorando o resultado caso o widget ja tenha sido
  /// desmontado.
  Future<void> _loadFormData() async {
    final loader = widget.onLoadFormData;
    if (loader == null) return;

    setState(() => _isLoadingFormData = true);

    try {
      final data = await loader();
      if (!mounted) return;

      setState(() {
        _nomeController.text = data.nome ?? _nomeController.text;
        _tipoElementoOptions = _resolveOptions(
          current: _tipoElementoOptions,
          incoming: data.tipoElementoOptions,
        );
        _tipologiaOptions = _resolveOptions(
          current: _tipologiaOptions,
          incoming: data.tipologiaOptions,
        );
        _localOptions = _resolveOptions(
          current: _localOptions,
          incoming: data.localOptions,
        );
        _revestimentoOptions = _resolveOptions(
          current: _revestimentoOptions,
          incoming: data.revestimentoOptions,
        );
        _tipoElemento = data.tipoElemento ?? _tipoElemento;
        _tipologiaEstrutural = data.tipologiaEstrutural ?? _tipologiaEstrutural;
        _localElemento = data.localElemento ?? _localElemento;
        _revestimento = data.revestimento ?? _revestimento;
        _sanitizeSelections();
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Erro ao carregar dados da tela: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoadingFormData = false);
      }
    }
  }

  /// Solicita a criacao de uma nova opcao para o dropdown informado e, se a
  /// resposta vier preenchida, adiciona essa opcao a lista correspondente e a
  /// seleciona imediatamente.
  Future<void> _handleAddOption(EstruturalDropdownField field) async {
    if (_fieldBeingAdded != null) return;

    String? novaOpcao;

    if (field == EstruturalDropdownField.localElemento) {
      // Local tem um cadastro mais rico (tipologia/condição); reaproveitamos
      // o modal dedicado, que agora devolve o nome do local criado.
      novaOpcao = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.42),
        builder: (_) => const NovoLocalModal(),
      );
    } else if (widget.onAddOption != null) {
      // Hook injetado (ex.: persistir no backend) tem prioridade quando existe.
      setState(() => _fieldBeingAdded = field);
      try {
        novaOpcao = await widget.onAddOption!(field);
      } catch (error) {
        if (mounted) _showSnackBar('Erro ao adicionar opção: $error');
      } finally {
        if (mounted) setState(() => _fieldBeingAdded = null);
      }
    } else {
      // Tipo/Tipologia/Revestimento: opção é apenas texto livre.
      novaOpcao = await showNovaOpcaoModal(
        context,
        titulo: _tituloNovaOpcao(field),
      );
    }

    if (!mounted || novaOpcao == null) return;
    final normalizedOption = novaOpcao.trim();
    if (normalizedOption.isEmpty) return;

    setState(() {
      final list = _getOptionsList(field);
      if (!list.contains(normalizedOption)) {
        list.add(normalizedOption);
      }
      _setSelectedValue(field, normalizedOption);
    });
  }

  /// Título do popup de nova opção conforme o campo.
  String _tituloNovaOpcao(EstruturalDropdownField field) {
    switch (field) {
      case EstruturalDropdownField.tipoElemento:
        return 'Novo Tipo de Elemento';
      case EstruturalDropdownField.tipologiaEstrutural:
        return 'Nova Tipologia Estrutural';
      case EstruturalDropdownField.localElemento:
        return 'Novo Local na Estrutura';
      case EstruturalDropdownField.revestimento:
        return 'Novo Revestimento';
    }
  }

  /// Indica se o botão "Criar" consegue salvar: ou há um [onSubmit] injetado,
  /// ou há uma [estruturaId] para o salvamento padrão via repository.
  bool get _canSubmit =>
      widget.onSubmit != null || widget.estruturaId != null;

  /// Fluxo de marcação em planta: primeiro o usuário escolhe a planta/formato
  /// (cards mockados), depois posiciona a marcação sobre a planta escolhida.
  Future<void> _handleAddMarcacao() async {
    final planta = await showSelecionarPlantaPopup(context);
    if (planta == null || !mounted) return;

    final resultado = await showMarcacaoPlantaPopup(
      context,
      plantaAsset: planta.plantaAsset ?? kPlantaMockAsset,
      inicial: _marcacaoPlanta,
    );
    if (resultado == null || !mounted) return;
    setState(() => _marcacaoPlanta = resultado);
    _showSnackBar('Marcação adicionada à planta.');
  }

  /// Monta o rascunho atual do formulario e o persiste.
  ///
  /// Usa o [onSubmit] injetado quando existir; caso contrário, grava o
  /// elemento diretamente na estrutura via [elementoRepositoryProvider].
  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    final draft = NovoElemEstruturalDraft(
      nome: _nomeController.text.trim(),
      tipoElemento: _tipoElemento,
      tipologiaEstrutural: _tipologiaEstrutural,
      localElemento: _localElemento,
      revestimento: _revestimento,
      marcacao: _marcacaoPlanta,
    );

    setState(() => _isSubmitting = true);

    try {
      final onSubmit = widget.onSubmit;
      if (onSubmit != null) {
        await onSubmit(draft);
      } else {
        await _criarElementoPadrao(draft);
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Erro ao salvar elemento: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Salvamento padrão: cria o elemento na estrutura atual.
  Future<void> _criarElementoPadrao(NovoElemEstruturalDraft draft) async {
    final estruturaId = widget.estruturaId;
    if (estruturaId == null) return;

    await ref.read(elementoRepositoryProvider).criarElemento(
          ElementoModel(
            id: '',
            nome: draft.nome.isEmpty ? null : draft.nome,
            tipo: draft.tipoElemento,
            tipologiaEstrutural: draft.tipologiaEstrutural,
            local: draft.localElemento,
            revestimento: draft.revestimento,
            ativo: true,
            // Backend preparado: a marcação na planta mapeia para posicao_x/y.
            // Já há colunas no banco; descomente quando o fluxo for liberado.
            // posicaoX: draft.marcacao?.x,
            // posicaoY: draft.marcacao?.y,
          ),
          estruturaId,
        );

    // Garante que a lista da estrutura reflita o novo elemento mesmo sem realtime.
    ref.invalidate(elementosPorEstruturaProvider(estruturaId));
  }

  /// Retorna a lista mutavel de opcoes correspondente ao campo recebido.
  List<String> _getOptionsList(EstruturalDropdownField field) {
    switch (field) {
      case EstruturalDropdownField.tipoElemento:
        return _tipoElementoOptions;
      case EstruturalDropdownField.tipologiaEstrutural:
        return _tipologiaOptions;
      case EstruturalDropdownField.localElemento:
        return _localOptions;
      case EstruturalDropdownField.revestimento:
        return _revestimentoOptions;
    }
  }

  /// Atualiza o valor selecionado de um dos dropdowns controlados pela tela.
  void _setSelectedValue(EstruturalDropdownField field, String? value) {
    switch (field) {
      case EstruturalDropdownField.tipoElemento:
        _tipoElemento = value;
      case EstruturalDropdownField.tipologiaEstrutural:
        _tipologiaEstrutural = value;
      case EstruturalDropdownField.localElemento:
        _localElemento = value;
      case EstruturalDropdownField.revestimento:
        _revestimento = value;
    }
  }

  /// Garante que as selecoes atuais ainda existam nas listas de opcoes.
  ///
  /// Se algum valor inicial nao estiver mais presente, ele e limpo para evitar
  /// estados inconsistentes no formulario.
  void _sanitizeSelections() {
    if (!_tipoElementoOptions.contains(_tipoElemento)) {
      _tipoElemento = null;
    }
    if (!_tipologiaOptions.contains(_tipologiaEstrutural)) {
      _tipologiaEstrutural = null;
    }
    if (!_localOptions.contains(_localElemento)) {
      _localElemento = null;
    }
    if (!_revestimentoOptions.contains(_revestimento)) {
      _revestimento = null;
    }
  }

  /// Exibe uma mensagem breve na tela via SnackBar.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mantem lista atual quando carga remota nao trouxer opcoes novas.
  List<String> _resolveOptions({
    required List<String> current,
    required List<String> incoming,
  }) {
    if (incoming.isEmpty) {
      return current;
    }
    return List<String>.from(incoming);
  }

  /// Converte uma lista simples de strings em itens prontos para um dropdown.
  List<DropdownMenuItem<String>> _buildDropdownItems(List<String> options) {
    return options
        .map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList();
  }

  /// Monta um dropdown estrutural padronizado com suporte a add assíncrono.
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required EstruturalDropdownField field,
  }) {
    final isAddingThisField = _fieldBeingAdded == field;
    final isAddEnabled =
        !_isLoadingFormData && !_isSubmitting && _fieldBeingAdded == null;

    return CustomDropdownWithAdd<String>(
      label: label,
      hint: 'Selecione',
      value: value,
      items: _buildDropdownItems(options),
      onChanged: (newValue) {
        if (_isLoadingFormData || _isSubmitting) return;
        setState(() => _setSelectedValue(field, newValue));
      },
      onAddPressed: () => _handleAddOption(field),
      isAddEnabled: isAddEnabled || isAddingThisField,
      isAdding: isAddingThisField,
    );
  }

  /// Construi a interface da tela com o cabeçalho fixo, o formulario e os
  /// botoes de acao.
  @override
  Widget build(BuildContext context) {
    return RightMenuBar(
      key: _rightMenuKey,
      onInformacoesPressed: widget.onOpenInformacoes,
      onRelatoriosPressed: widget.onOpenRelatorios,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppColors.primary,
        ),
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(25, 120, 25, 120),
                      child: Column(
                        children: [
                          Text(
                            'Novo Elemento Estrutural',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              color: const Color(0xFF3E3E3D),
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _ElementoAvatar(
                            onPressed: widget.onAvatarEditPressed,
                          ),
                          const SizedBox(height: 24),
                          CustomTextField(
                            label: 'Nome do Elemento',
                            hint: 'Digite o nome',
                            controller: _nomeController,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Tipo do Elemento',
                            value: _tipoElemento,
                            options: _tipoElementoOptions,
                            field: EstruturalDropdownField.tipoElemento,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Tipologia Estrutural',
                            value: _tipologiaEstrutural,
                            options: _tipologiaOptions,
                            field: EstruturalDropdownField.tipologiaEstrutural,
                          ),
                          const SizedBox(height: 10),
                          _buildDropdownField(
                            label: 'Local do Elemento',
                            value: _localElemento,
                            options: _localOptions,
                            field: EstruturalDropdownField.localElemento,
                          ),
                          const SizedBox(height: 18),
                          _PlanImageCard(
                            onPressed: widget.onPlanPressed ?? _handleAddMarcacao,
                            marcacao: _marcacaoPlanta,
                          ),
                          const SizedBox(height: 18),
                          BiggerCustomButton(
                            text: 'Adicionar marcacao em Planta',
                            width: 292,
                            height: 40,
                            onPressed:
                                widget.onAddMarcacaoPressed ?? _handleAddMarcacao,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownField(
                            label: 'Revestimento',
                            value: _revestimento,
                            options: _revestimentoOptions,
                            field: EstruturalDropdownField.revestimento,
                          ),
                          const SizedBox(height: 24),
                          BiggerCustomButton(
                            text: _isSubmitting ? 'Salvando...' : 'Criar',
                            width: 139,
                            height: 54,
                            onPressed: (_isSubmitting || !_canSubmit)
                                ? () {}
                                : _handleSubmit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _EstruturaHeader(
                    onMenuPressed: () => _rightMenuKey.currentState?.toggle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabecalho fixo da tela com navegação, titulo e icones decorativos.
class _EstruturaHeader extends StatelessWidget {
  /// Cria o cabecalho sem estado.
  const _EstruturaHeader({this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  /// Monta a faixa superior com o nome do modulo e as acoes visuais.
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Projeto',
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Estrutura',
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  Text(
                    'Novo Elemento',
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.notifications_none, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: onMenuPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar ilustrativo do elemento estrutural com acao de edicao opcional.
class _ElementoAvatar extends StatelessWidget {
  /// Cria o avatar clicavel.
  const _ElementoAvatar({this.onPressed});

  final VoidCallback? onPressed;

  /// Exibe o circulo com o icone do edificio e o botao de edicao sobreposto.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: SizedBox(
        width: 123,
        height: 123,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 123,
              height: 123,
              decoration: const BoxDecoration(
                color: Color(0xFFD9D9D9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.location_city_outlined,
                  size: 64,
                  color: AppColors.greyDarkest.withOpacity(0.8),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.greyDarkest.withOpacity(0.9),
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartao ilustrado que representa a planta e dispara uma acao ao tocar.
class _PlanImageCard extends StatelessWidget {
  /// Cria o cartao da planta com callback obrigatorio.
  const _PlanImageCard({this.onPressed, this.marcacao});

  final VoidCallback? onPressed;
  final MarcacaoPlanta? marcacao;

  /// Renderiza uma imagem da planta com moldura e area clicavel.
  @override
  Widget build(BuildContext context) {
    final marcacao = this.marcacao;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 279,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          border: Border.all(color: const Color(0xFF858585)),
        ),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    kPlantaMockAsset,
                    fit: BoxFit.cover,
                  ),
                  if (marcacao != null)
                    Positioned(
                      left: (marcacao.x * w) - 11,
                      top: (marcacao.y * h) - 11,
                      child: MarcacaoBolinha(numero: marcacao.numero, tamanho: 22),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Identifica qual dropdown estrutural esta sendo manipulado.
enum EstruturalDropdownField {
  tipoElemento,
  tipologiaEstrutural,
  localElemento,
  revestimento,
}

/// Dados iniciais recebidos para popular a tela do formulario.
class NovoElemEstruturalFormData {
  /// Cria um pacote de dados com selecoes e listas opcionais.
  const NovoElemEstruturalFormData({
    this.nome,
    this.tipoElemento,
    this.tipologiaEstrutural,
    this.localElemento,
    this.revestimento,
    this.tipoElementoOptions = const <String>[],
    this.tipologiaOptions = const <String>[],
    this.localOptions = const <String>[],
    this.revestimentoOptions = const <String>[],
  });

  final String? nome;
  final String? tipoElemento;
  final String? tipologiaEstrutural;
  final String? localElemento;
  final String? revestimento;
  final List<String> tipoElementoOptions;
  final List<String> tipologiaOptions;
  final List<String> localOptions;
  final List<String> revestimentoOptions;
}

/// Rascunho final do elemento estrutural pronto para envio.
class NovoElemEstruturalDraft {
  /// Cria um rascunho com os campos finais do formulario.
  const NovoElemEstruturalDraft({
    required this.nome,
    required this.tipoElemento,
    required this.tipologiaEstrutural,
    required this.localElemento,
    required this.revestimento,
    this.marcacao,
  });

  final String nome;
  final String? tipoElemento;
  final String? tipologiaEstrutural;
  final String? localElemento;
  final String? revestimento;

  /// Marcação na planta, quando definida pelo usuário. Mapeia para
  /// `posicao_x`/`posicao_y` no backend (ver [MarcacaoPlanta]).
  final MarcacaoPlanta? marcacao;

  /// Converte o rascunho em mapa para persistencia ou envio em API.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nome': nome,
      'tipoElemento': tipoElemento,
      'tipologiaEstrutural': tipologiaEstrutural,
      'localElemento': localElemento,
      'revestimento': revestimento,
      if (marcacao != null) ...marcacao!.toPosicaoMap(),
    };
  }
}
