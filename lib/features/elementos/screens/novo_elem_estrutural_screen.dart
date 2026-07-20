import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:diavicon/core/widgets/custom_text_field.dart';
import 'package:diavicon/features/elementos/widgets/bigger_custom_button.dart';
import 'package:diavicon/features/elementos/widgets/marcacao_planta_popup.dart';
import 'package:diavicon/features/elementos/widgets/nova_opcao_modal.dart';
import 'package:diavicon/features/elementos/widgets/novo_local_widget.dart';
import 'package:diavicon/features/elementos/widgets/novo_tipo_elemento_modal.dart';
import 'package:diavicon/features/elementos/widgets/selecionar_planta_popup.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/widgets/right_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:image_cropper/image_cropper.dart'; 

const List<String> _defaultTipoElementoOptions = <String>[
  'Pilar',
  'Viga',
  'Laje',
];

const List<String> _defaultTipologiaOptions = <String>[
  'Concreto armado',
  'Metalica',
  'Mista',
];

const List<String> _defaultLocalOptions = <String>[
  'Interno',
  'Externo',
  'Cobertura',
];

const List<String> _defaultRevestimentoOptions = <String>[
  'Pintura',
  'Argamassa',
  'Ceramica',
];

class NovoElemEstruturalScreen extends ConsumerStatefulWidget {
  const NovoElemEstruturalScreen({
    super.key,
    this.estruturaId,
    this.initialNome = '', 
    this.initialMarcacao,  
    this.initialPlantaUrl, 
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

  final String? estruturaId;
  final String initialNome;
  final MarcacaoPlanta? initialMarcacao; 
  final String? initialPlantaUrl;        
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

  @override
  ConsumerState<NovoElemEstruturalScreen> createState() =>
      _NovoElemEstruturalScreenState();
}

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

  MarcacaoPlanta? _marcacaoPlanta;
  String? _plantaUrlSelecionada; 

  XFile? _fotoElemento;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.initialNome);

    _nomeController.addListener(() {
      if (mounted) setState(() {});
    });
    
    _marcacaoPlanta = widget.initialMarcacao;
    _plantaUrlSelecionada = widget.initialPlantaUrl;

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

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Foto do Elemento',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false, 
          ),
          IOSUiSettings(
            title: 'Ajustar Foto',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _fotoElemento = XFile(croppedFile.path);
        });
      }
    }
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

  Future<void> _handleAddOption(EstruturalDropdownField field) async {
    if (_fieldBeingAdded != null) return;

    String? novaOpcao;

    if (field == EstruturalDropdownField.localElemento) {
      novaOpcao = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.42),
        builder: (_) => const NovoLocalModal(),
      );
    } else if (field == EstruturalDropdownField.tipoElemento) {
      novaOpcao = await showDialog<String>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.42),
        builder: (_) => const NovoTipoElementoModal(),
      );
    } else if (widget.onAddOption != null) {
      setState(() => _fieldBeingAdded = field);
      try {
        novaOpcao = await widget.onAddOption!(field);
      } catch (error) {
        if (mounted) _showSnackBar('Erro ao adicionar opção: $error');
      } finally {
        if (mounted) setState(() => _fieldBeingAdded = null);
      }
    } else {
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

  bool get _canSubmit =>
      widget.onSubmit != null || widget.estruturaId != null;

  Future<void> _handleAddMarcacao() async {
    if (widget.estruturaId == null) return;

    String urlPlanta = _plantaUrlSelecionada ?? '';
    String idPlanta = _marcacaoPlanta?.plantaId ?? '';

    if (urlPlanta.isEmpty || idPlanta.isEmpty) {
      final planta = await showSelecionarPlantaPopup(context, widget.estruturaId!);
      if (planta == null || !mounted) return;
      
      urlPlanta = planta.arquivoUrl;
      idPlanta = planta.id;
    }

    // Pega o nome atual digitado no campo (se houver)
    final nomeDigitado = _nomeController.text.trim();

    final resultado = await showMarcacaoPlantaPopup(
      context,
      arquivoUrl: urlPlanta, 
      plantaId: idPlanta,          
      inicial: _marcacaoPlanta,
      nomeElemento: nomeDigitado.isNotEmpty ? nomeDigitado : null, 
    );

    if (resultado == null || !mounted) return;
    
    setState(() {
      _marcacaoPlanta = resultado;
      _plantaUrlSelecionada = urlPlanta; 
    });
    
    _showSnackBar('Posição da marcação atualizada.');
  }

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

  Future<void> _criarElementoPadrao(NovoElemEstruturalDraft draft) async {
    final estruturaId = widget.estruturaId;
    if (estruturaId == null) return;

    final repo = ref.read(elementoRepositoryProvider);
    List<String>? urlsDeFotos;

    if (_fotoElemento != null) {
      final elementoRefId = 'novo_${DateTime.now().millisecondsSinceEpoch}';
      final urlPublica = await repo.uploadFoto(
        elementoId: elementoRefId,
        caminhoLocalFoto: _fotoElemento!.path,
      );
      urlsDeFotos = [urlPublica];
    }

    await repo.criarElemento(
      ElementoModel(
        id: '',
        nome: draft.nome.isEmpty ? null : draft.nome,
        tipo: draft.tipoElemento,
        tipologiaEstrutural: draft.tipologiaEstrutural,
        local: draft.localElemento,
        revestimento: draft.revestimento,
        fotos: urlsDeFotos, 
        posicaoX: draft.marcacao?.x, 
        posicaoY: draft.marcacao?.y,
        plantaId: draft.marcacao?.plantaId, 
        tipoMarcacao: draft.marcacao?.tipoMarcacao, 
        ativo: true,
      ),
      estruturaId,
    );

    ref.invalidate(elementosPorEstruturaProvider(estruturaId));
  }

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

  @override
  Widget build(BuildContext context) {
    final nomeAtual = _nomeController.text.trim();

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
                            foto: _fotoElemento,
                            onPressed: widget.onAvatarEditPressed ?? _selecionarFoto,
                          ),
                          const SizedBox(height: 24),
                          
                          CustomTextField(
                            label: 'Nome do Elemento',
                            hint: 'Digite o nome',
                            controller: _nomeController,
                            // Atualiza a tela se digitar o nome para o Card da Planta pegar!
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
                            arquivoUrl: _plantaUrlSelecionada,
                            nomeElemento: nomeAtual.isNotEmpty ? nomeAtual : null,
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

class _EstruturaHeader extends StatelessWidget {
  const _EstruturaHeader({this.onMenuPressed});

  final VoidCallback? onMenuPressed;

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

class _ElementoAvatar extends StatelessWidget {
  const _ElementoAvatar({this.onPressed, this.foto});

  final VoidCallback? onPressed;
  final XFile? foto;

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
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                shape: BoxShape.circle,
                image: foto != null
                    ? DecorationImage(
                        image: FileImage(File(foto!.path)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: foto == null
                  ? Center(
                      child: Icon(
                        Icons.location_city_outlined,
                        size: 64,
                        color: AppColors.greyDarkest.withOpacity(0.8),
                      ),
                    )
                  : null,
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

class _PlanImageCard extends StatelessWidget {
  const _PlanImageCard({this.onPressed, this.marcacao, this.arquivoUrl, this.nomeElemento});

  final VoidCallback? onPressed;
  final MarcacaoPlanta? marcacao;
  final String? arquivoUrl;
  final String? nomeElemento; 

  @override
  Widget build(BuildContext context) {
    final marcacao = this.marcacao;
    final url = arquivoUrl;
    final isPdf = url != null && url.toLowerCase().contains('.pdf');
    final bytesThumbnail = marcacao?.thumbnailBytes; 

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
              
              final temFundoReal = (bytesThumbnail != null) || (url != null && !isPdf);

              return Stack(
                fit: StackFit.expand,
                children: [
                  if (bytesThumbnail != null)
                    Image.memory(bytesThumbnail, fit: BoxFit.cover)
                  else if (url != null && !isPdf)
                    Image.network(url, fit: BoxFit.cover)
                  else if (isPdf)
                    const Center(child: Icon(Icons.picture_as_pdf_outlined, size: 48, color: Color(0xFF3E3E3D)))
                  else
                    const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    
                  if (marcacao != null && temFundoReal)
                    Positioned(
                      left: (marcacao.x * w) - 13, // Ajustado de 11 para 13 (metade de 26)
                      top: (marcacao.y * h) - 13,
                      child: PinoDinamico(
                        tipoMarcacao: marcacao.tipoMarcacao, 
                        nomeElemento: nomeElemento, 
                        numero: marcacao.numero
                      ),
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

enum EstruturalDropdownField {
  tipoElemento,
  tipologiaEstrutural,
  localElemento,
  revestimento,
}

class NovoElemEstruturalFormData {
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

class NovoElemEstruturalDraft {
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
  final MarcacaoPlanta? marcacao;

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