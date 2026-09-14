import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/core/widgets/menu_app_bar.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
import 'package:diavicon/features/elementos/widgets/novo_local_widget.dart';
import 'package:diavicon/features/elementos/widgets/right_menu_bar.dart';
import 'package:diavicon/features/empresa/providers/campos_personalizaveis_provider.dart';
import 'package:diavicon/features/empresa/providers/sistema_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const List<String> _defaultTipoElementoOptions = <String>[];

const List<String> _defaultTipologiaOptions = <String>[];

const List<String> _defaultLocalOptions = <String>[];

const List<String> _defaultRevestimentoOptions = <String>[];

class ElementoInfoScreen extends ConsumerStatefulWidget {
  const ElementoInfoScreen({
    super.key,
    this.initialNome = 'ABC Corp.',
    this.initialTipoElemento,
    this.initialTipologiaEstrutural,
    this.initialLocalElemento,
    this.initialRevestimento,
    this.initialMarcacaoImagemUrl,
    this.initialTipoElementoOptions = _defaultTipoElementoOptions,
    this.initialTipologiaOptions = _defaultTipologiaOptions,
    this.initialLocalOptions = _defaultLocalOptions,
    this.initialRevestimentoOptions = _defaultRevestimentoOptions,
    this.onLoadFormData,
    this.onAddOption,
    this.onSubmit,
    this.onBannerEditPressed,
    this.onPlanPressed,
    this.onAddMarcacaoPressed,
    this.onOpenRelatorios,
  });

  final String initialNome;
  final String? initialTipoElemento;
  final String? initialTipologiaEstrutural;
  final String? initialLocalElemento;
  final String? initialRevestimento;
  final String? initialMarcacaoImagemUrl;
  final List<String> initialTipoElementoOptions;
  final List<String> initialTipologiaOptions;
  final List<String> initialLocalOptions;
  final List<String> initialRevestimentoOptions;
  final Future<ElementoInfoFormData> Function()? onLoadFormData;
  final Future<String?> Function(ElementoInfoDropdownField field)? onAddOption;
  final Future<void> Function(ElementoInfoDraft draft)? onSubmit;
  final VoidCallback? onBannerEditPressed;
  final VoidCallback? onPlanPressed;
  final VoidCallback? onAddMarcacaoPressed;
  final VoidCallback? onOpenRelatorios;

  @override
  ConsumerState<ElementoInfoScreen> createState() => _ElementoInfoScreenState();
}

class _ElementoInfoScreenState extends ConsumerState<ElementoInfoScreen> {
  final GlobalKey<RightMenuBarState> _rightMenuKey =
      GlobalKey<RightMenuBarState>();
  late final TextEditingController _nomeController;

  String? _sistemaHabitacional;
  String? _tipoElemento;
  String? _tipologiaEstrutural;
  String? _localElemento;
  String? _revestimento;
  String? _marcacaoImagemUrl;

  List<String> _tipoElementoOptions = <String>[];
  List<String> _tipologiaOptions = <String>[];
  List<String> _localOptions = <String>[];
  List<String> _revestimentoOptions = <String>[];

  bool _isLoadingFormData = false;
  bool _isSubmitting = false;
  ElementoInfoDropdownField? _fieldBeingAdded;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.initialNome);
    _tipoElemento = widget.initialTipoElemento;
    _tipologiaEstrutural = widget.initialTipologiaEstrutural;
    _localElemento = widget.initialLocalElemento;
    _revestimento = widget.initialRevestimento;
    _marcacaoImagemUrl = widget.initialMarcacaoImagemUrl;
    _tipoElementoOptions = List<String>.from(widget.initialTipoElementoOptions);
    _tipologiaOptions = List<String>.from(widget.initialTipologiaOptions);
    _localOptions = List<String>.from(widget.initialLocalOptions);
    _revestimentoOptions = List<String>.from(widget.initialRevestimentoOptions);
    _sanitizeSelections();
    _loadFormData();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

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
        _marcacaoImagemUrl = data.marcacaoImagemUrl ?? _marcacaoImagemUrl;
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

  void _handleSistemaHabitacionalChanged(String? novoSistema) {
    setState(() {
      _sistemaHabitacional = novoSistema;

      final empresaId = ref.read(currentUserProvider)?.empresaId;
      if (novoSistema != null && _tipoElemento != null && empresaId != null) {
        final tipos = ref
            .read(tiposElementoDropdownProvider(empresaId))
            .value;
        final aindaValido =
            tipos?.any(
              (t) => t.nome == _tipoElemento && t.sistemaId == novoSistema,
            ) ??
            false;
        if (!aindaValido) {
          _tipoElemento = null;
        }
      }
    });
  }

  Future<void> _handleAddOption(ElementoInfoDropdownField field) async {
    if (field == ElementoInfoDropdownField.localElemento) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        builder: (_) => const NovoLocalModal(),
      );
      return;
    }

    final onAddOption = widget.onAddOption;
    if (onAddOption == null || _fieldBeingAdded != null) return;

    setState(() => _fieldBeingAdded = field);

    try {
      final newOption = await onAddOption(field);
      if (!mounted || newOption == null) return;

      final normalizedOption = newOption.trim();
      if (normalizedOption.isEmpty) return;

      setState(() {
        final list = _getOptionsList(field);
        if (!list.contains(normalizedOption)) {
          list.add(normalizedOption);
        }
        _setSelectedValue(field, normalizedOption);
      });
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Erro ao adicionar opcao: $error');
    } finally {
      if (mounted) {
        setState(() => _fieldBeingAdded = null);
      }
    }
  }

  Future<void> _handleSubmit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) return;

    setState(() => _isSubmitting = true);

    try {
      await onSubmit(
        ElementoInfoDraft(
          nome: _nomeController.text.trim(),
          tipoElemento: _tipoElemento,
          tipologiaEstrutural: _tipologiaEstrutural,
          localElemento: _localElemento,
          revestimento: _revestimento,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Erro ao salvar elemento: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  List<String> _getOptionsList(ElementoInfoDropdownField field) {
    switch (field) {
      case ElementoInfoDropdownField.tipoElemento:
        return _tipoElementoOptions;
      case ElementoInfoDropdownField.tipologiaEstrutural:
        return _tipologiaOptions;
      case ElementoInfoDropdownField.localElemento:
        return _localOptions;
      case ElementoInfoDropdownField.revestimento:
        return _revestimentoOptions;
    }
  }

  void _setSelectedValue(ElementoInfoDropdownField field, String? value) {
    switch (field) {
      case ElementoInfoDropdownField.tipoElemento:
        _tipoElemento = value;
      case ElementoInfoDropdownField.tipologiaEstrutural:
        _tipologiaEstrutural = value;
      case ElementoInfoDropdownField.localElemento:
        _localElemento = value;
      case ElementoInfoDropdownField.revestimento:
        _revestimento = value;
    }
  }

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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _resolveOptions({
    required List<String> current,
    required List<String> incoming,
  }) {
    if (incoming.isEmpty) {
      return current;
    }
    return List<String>.from(incoming);
  }

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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required ElementoInfoDropdownField field,
  }) {
    final isAddingThisField = _fieldBeingAdded == field;
    final isAddEnabled =
        !_isLoadingFormData &&
        !_isSubmitting &&
        widget.onAddOption != null &&
        _fieldBeingAdded == null;

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

  @override
  Widget build(BuildContext context) {
    final topContentPadding = MediaQuery.paddingOf(context).top + 124;

    final empresaId = ref.watch(currentUserProvider)?.empresaId;
    final sistemasAsync = empresaId == null
        ? null
        : ref.watch(sistemasDropdownProvider(empresaId));
    final tiposElementoAsync = empresaId == null
        ? null
        : ref.watch(tiposElementoDropdownProvider(empresaId));

    final tiposDoSistema = (tiposElementoAsync?.value ?? const <CampoItemModel>[])
        .where(
          (t) => _sistemaHabitacional == null || t.sistemaId == _sistemaHabitacional,
        )
        .map((t) => t.nome);
    final tiposFinais = {..._tipoElementoOptions, ...tiposDoSistema}.toList();

    return RightMenuBar(
      key: _rightMenuKey,
      onInformacoesPressed: () {},
      onRelatoriosPressed: widget.onOpenRelatorios,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: AppColors.primary,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          extendBodyBehindAppBar: true,
          appBar: MenuAppBar(
            title: 'Elemento',
            topTitle: 'Projeto',
            bottomTitle: 'Informações',
            onMenuPressed: () => _rightMenuKey.currentState?.toggle(),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, topContentPadding, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ElementoBanner(onEditPressed: widget.onBannerEditPressed),
                  const SizedBox(height: 22),
                  CustomTextField(
                    label: 'Nome do Elemento',
                    hint: 'ABC Corp.',
                    controller: _nomeController,
                  ),
                  const SizedBox(height: 18),
                  CustomDropdownWithAdd<String>(
                    label: 'Sistema Habitacional',
                    hint: 'Selecione',
                    value: _sistemaHabitacional,
                    items: (sistemasAsync?.value ?? const <CampoItemModel>[])
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.nome, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (_isLoadingFormData || _isSubmitting)
                        ? null
                        : _handleSistemaHabitacionalChanged,
                    onAddPressed: () {},
                    isAddEnabled: false,
                  ),
                  const SizedBox(height: 18),
                  _buildDropdownField(
                    label: 'Tipo do Elemento',
                    value: _tipoElemento,
                    options: tiposFinais,
                    field: ElementoInfoDropdownField.tipoElemento,
                  ),
                  const SizedBox(height: 18),
                  _buildDropdownField(
                    label: 'Tipologia Estrutural',
                    value: _tipologiaEstrutural,
                    options: _tipologiaOptions,
                    field: ElementoInfoDropdownField.tipologiaEstrutural,
                  ),
                  const SizedBox(height: 18),
                  _buildDropdownField(
                    label: 'Local do Elemento',
                    value: _localElemento,
                    options: _localOptions,
                    field: ElementoInfoDropdownField.localElemento,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: _PlantaCard(
                      imageUrl: _marcacaoImagemUrl,
                      onPressed: widget.onPlanPressed,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: BiggerCustomButton(
                      width: 292,
                      height: 40,
                      text: 'Adicionar marcação em Planta',
                      onPressed: widget.onAddMarcacaoPressed ?? () {},
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildDropdownField(
                    label: 'Revestimento',
                    value: _revestimento,
                    options: _revestimentoOptions,
                    field: ElementoInfoDropdownField.revestimento,
                  ),
                  const SizedBox(height: 44),
                  Center(
                    child: BiggerCustomButton(
                      width: 139,
                      height: 52,
                      text: _isSubmitting ? 'Salvando...' : 'Criar',
                      onPressed: _isSubmitting
                          ? () {}
                          : (widget.onSubmit == null ? () {} : _handleSubmit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElementoBanner extends StatelessWidget {
  const _ElementoBanner({this.onEditPressed});

  final VoidCallback? onEditPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 122,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            image: const DecorationImage(
              image: AssetImage('assets/images/elemento_info.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: -18,
          child: Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onEditPressed,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  Icons.edit_outlined,
                  color: AppColors.greyDarkest.withValues(alpha: 0.95),
                  size: 31,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlantaCard extends StatelessWidget {
  const _PlantaCard({this.imageUrl, this.onPressed});

  final String? imageUrl;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 279,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          border: Border.all(color: const Color(0xFFD1D1D1), width: 4),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF5E5E5E), width: 1),
          ),
          child: _PlantaCardImage(imageUrl: imageUrl),
        ),
      ),
    );
  }
}

class _PlantaCardImage extends StatelessWidget {
  const _PlantaCardImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => Image.asset(
    'assets/images/planta_elementos_info.png',
    fit: BoxFit.cover,
  );
}

enum ElementoInfoDropdownField {
  tipoElemento,
  tipologiaEstrutural,
  localElemento,
  revestimento,
}

class ElementoInfoFormData {
  const ElementoInfoFormData({
    this.nome,
    this.tipoElemento,
    this.tipologiaEstrutural,
    this.localElemento,
    this.revestimento,
    this.marcacaoImagemUrl,
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
  final String? marcacaoImagemUrl;
  final List<String> tipoElementoOptions;
  final List<String> tipologiaOptions;
  final List<String> localOptions;
  final List<String> revestimentoOptions;
}

class ElementoInfoDraft {
  const ElementoInfoDraft({
    required this.nome,
    required this.tipoElemento,
    required this.tipologiaEstrutural,
    required this.localElemento,
    required this.revestimento,
  });

  final String nome;
  final String? tipoElemento;
  final String? tipologiaEstrutural;
  final String? localElemento;
  final String? revestimento;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nome': nome,
      'tipoElemento': tipoElemento,
      'tipologiaEstrutural': tipologiaEstrutural,
      'localElemento': localElemento,
      'revestimento': revestimento,
    };
  }
}
