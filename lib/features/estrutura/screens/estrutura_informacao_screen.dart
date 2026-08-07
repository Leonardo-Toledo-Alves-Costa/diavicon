import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_dropdown.dart';
import '../../../core/widgets/custom_dropdown_with_add.dart';
import '../../../core/widgets/diavicon_alerts.dart';

import '../models/estrutura_model.dart';
import '../widgets/proprietario_vinculo_section.dart';
import '../widgets/header_imagem_editavel.dart';
import '../widgets/mapa_preview_widget.dart';
import '../widgets/estrutura_home_header.dart';

// 🔥 IMPORT DOS PROVIDERS PARA VALIDAR SE A EMPRESA É A GESTORA 
import '../../projetos/providers/projetos_provider.dart'; 
import '../../auth/providers/auth_provider.dart'; 
// 🔥 IMPORT DO REPOSITÓRIO PARA SALVAR E PROVIDER DE ESTRUTURAS
import '../providers/estrutura_provider.dart'; 

class EstruturaInformacaoScreen extends ConsumerStatefulWidget {
  final EstruturaModel estrutura;
  final String projetoId;

  const EstruturaInformacaoScreen({
    super.key,
    required this.estrutura,
    required this.projetoId,
  });

  @override
  ConsumerState<EstruturaInformacaoScreen> createState() =>
      _EstruturaInformacaoScreenState();
}

class _EstruturaInformacaoScreenState extends ConsumerState<EstruturaInformacaoScreen> {
  final double _fieldSpacing = 16.0;

  // Controladores de Texto
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _idadeController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _numeroController = TextEditingController();
  final _paisController = TextEditingController();
  final _ufController = TextEditingController();
  final _caaController = TextEditingController();
  
  final _conjuntoController = TextEditingController();
  final _utilizacaoController = TextEditingController();
  final _tipoController = TextEditingController();
  final _tipologiaController = TextEditingController();

  File? _novaImagemCapa;
  bool _isSaving = false;
  bool _isInitialized = false;

  // Variáveis para otimização de renderização
  bool _isDirty = false; 
  EstruturaModel? _estruturaSalva;

  // Variáveis para guardar o estado inicial e comparar alterações
  late String _initialNome;
  late String _initialDesc;
  late String _initialIdade;
  late String _initialLat;
  late String _initialLong;
  late String _initialCep;
  late String _initialEnd;
  late String _initialCid;
  late String _initialNum;
  late String _initialPais;
  late String _initialUf;
  late String _initialCaa;

  String? _clean(String? val) => (val != null && val.trim().isNotEmpty) ? val : null;

  @override
  void initState() {
    super.initState();
    _preencherControladores(widget.estrutura);
    _adicionarListeners();
  }

  void _preencherControladores(EstruturaModel e) {
    _initialNome = e.nome ?? '';
    _initialDesc = e.descricao ?? '';
    _initialIdade = e.anoConcepcao?.toString() ?? '';
    _initialLat = e.latitude?.toString() ?? '';
    _initialLong = e.longitude?.toString() ?? '';
    _initialCep = e.cep ?? '';
    _initialEnd = e.endereco ?? '';
    _initialCid = e.cidade ?? '';
    _initialNum = e.numero ?? '';
    _initialPais = e.pais ?? '';
    _initialUf = e.uf ?? '';
    _initialCaa = e.caa ?? '';

    _nomeController.text = _initialNome;
    _descricaoController.text = _initialDesc;
    _idadeController.text = _initialIdade;
    _latController.text = _initialLat;
    _longController.text = _initialLong;
    _cepController.text = _initialCep;
    _enderecoController.text = _initialEnd;
    _cidadeController.text = _initialCid;
    _numeroController.text = _initialNum;
    _paisController.text = _initialPais;
    _ufController.text = _initialUf;
    _caaController.text = _initialCaa;
    
    // Campos que eram fixos no form
    _conjuntoController.text = e.conjuntoNome ?? 'Não Informado';
    _utilizacaoController.text = e.utilizacaoNome ?? 'Não Informado';
    _tipoController.text = e.tipoNome ?? 'Não Informado';
    _tipologiaController.text = e.tipologiaNome ?? 'Não Informado';

    _isInitialized = true;
  }

  void _adicionarListeners() {
    final controllers = [
      _nomeController, _descricaoController, _idadeController, _latController,
      _longController, _cepController, _enderecoController, _cidadeController,
      _numeroController, _paisController, _ufController, _caaController
    ];
    for (var c in controllers) {
      c.addListener(_checarSeSujou);
    }
  }

  void _checarSeSujou() {
    final temMudanca = _hasChanges;
    if (_isDirty != temMudanca) {
      setState(() {
        _isDirty = temMudanca;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _idadeController.dispose();
    _latController.dispose();
    _longController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _cidadeController.dispose();
    _numeroController.dispose();
    _paisController.dispose();
    _ufController.dispose();
    _caaController.dispose();
    _conjuntoController.dispose();
    _utilizacaoController.dispose();
    _tipoController.dispose();
    _tipologiaController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (!_isInitialized) return false;
    if (_novaImagemCapa != null) return true;
    if (_nomeController.text != _initialNome) return true;
    if (_descricaoController.text != _initialDesc) return true;
    if (_idadeController.text != _initialIdade) return true;
    if (_latController.text != _initialLat) return true;
    if (_longController.text != _initialLong) return true;
    if (_cepController.text != _initialCep) return true;
    if (_enderecoController.text != _initialEnd) return true;
    if (_cidadeController.text != _initialCid) return true;
    if (_numeroController.text != _initialNum) return true;
    if (_paisController.text != _initialPais) return true;
    if (_ufController.text != _initialUf) return true;
    if (_caaController.text != _initialCaa) return true;
    return false;
  }

  Future<void> _verificarSaida() async {
    if (!_hasChanges) {
      Navigator.of(context).pop(_estruturaSalva);
      return;
    }

    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Alterações não salvas', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
        content: const Text('Você fez alterações que ainda não foram salvas. Se sair agora, perderá todas as mudanças. Deseja realmente sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ficar na Tela', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair sem salvar', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (sair == true && mounted) {
      Navigator.of(context).pop(_estruturaSalva);
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
      
      if (result != null && result.files.single.path != null) {
        final pickedFilePath = result.files.single.path!;

        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFilePath,
          aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), 
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Enquadrar Foto',
              toolbarColor: AppColors.primary, 
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: true, 
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Enquadrar Foto',
              aspectRatioLockEnabled: true, 
              resetButtonHidden: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _novaImagemCapa = File(croppedFile.path);
          });
          _checarSeSujou(); 
        }
      }
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro', 'Não foi possível selecionar a imagem: $e', isErro: true);
      }
    }
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);
    
    try {
      final repo = ref.read(estruturaRepositoryProvider);
      
      String? novaUrlFoto = widget.estrutura.imageUrl;
      if (_novaImagemCapa != null) {
        novaUrlFoto = await repo.uploadImagemEstrutura(_novaImagemCapa!);
      }

      final estruturaAtualizada = widget.estrutura.copyWith(
        nome: _clean(_nomeController.text),
        descricao: _clean(_descricaoController.text),
        anoConcepcao: int.tryParse(_idadeController.text),
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_longController.text),
        cep: _clean(_cepController.text),
        endereco: _clean(_enderecoController.text),
        cidade: _clean(_cidadeController.text),
        numero: _clean(_numeroController.text),
        pais: _clean(_paisController.text),
        uf: _clean(_ufController.text),
        caa: _clean(_caaController.text),
        imageUrl: novaUrlFoto,
      );

      await repo.atualizarEstrutura(estruturaAtualizada);
      ref.invalidate(estruturasDoProjetoProvider(widget.projetoId));

      if (mounted) {
        DiaviconAlerts.show(context, 'Sucesso!', 'Informações da estrutura atualizadas.');
        
        _estruturaSalva = estruturaAtualizada;

        setState(() {
          _preencherControladores(estruturaAtualizada);
          _novaImagemCapa = null; 
          _isSaving = false;
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        DiaviconAlerts.show(context, 'Erro ao salvar', e.toString().replaceAll('Exception: ', ''), isErro: true);
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double? latAtual = double.tryParse(_latController.text.trim());
    double? longAtual = double.tryParse(_longController.text.trim());
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 🔥 Descobre se o teclado está aberto
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final projetoAsync = ref.watch(projectDetailProvider(widget.projetoId));
    final usuarioEmpresaIdAsync = ref.watch(loggedUserCompanyIdProvider);
    
    bool canEdit = false;
    projetoAsync.whenData((projeto) {
      usuarioEmpresaIdAsync.whenData((empresaId) {
        canEdit = (projeto.empresaGestoraId == empresaId);
      });
    });

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _verificarSaida();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: CustomAppBar(
          title: 'Estrutura\nInformações',
          showBackButton: true,
          showMenuButton: false,
          showNotificationButton: false,
          onBackPressed: () => _verificarSaida(),

        ),
        
        bottomNavigationBar: _isDirty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: _isSaving
                      ? const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                        )
                      : CustomButton(
                          text: 'Salvar Alterações',
                          onPressed: _salvarAlteracoes,
                        ),
                ),
              )
            : null, 

        body: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomPadding + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_novaImagemCapa != null)
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        // 🔥 ResizeImage salva a memória aqui!
                        image: DecorationImage(
                          image: ResizeImage(FileImage(_novaImagemCapa!), width: 800),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    EstruturaHomeHeader(
                      imageUrl: widget.estrutura.imageUrl,
                      status: widget.estrutura.status ?? 'Pendente',
                    ),
                  
                  if (canEdit)
                    Positioned(
                      bottom: 15,
                      right: 15,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.edit_square, color: AppColors.textDark, size: 24),
                        ),
                      ),
                    ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Nome',
                          hint: 'Sem nome',
                          controller: _nomeController,
                          enabled: canEdit,
                        ),
                        SizedBox(height: _fieldSpacing),
                        const Text(
                          'Descrição',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.hintText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _descricaoController,
                          maxLines: 4,
                          enabled: canEdit,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: canEdit ? Colors.white : Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.inputBorder),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.inputBorder),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                    ProprietarioVinculoSection(projetoId: widget.projetoId),
                    const SizedBox(height: 24),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cadastro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: CustomTextField(
                                label: 'CAA',
                                hint: '-',
                                controller: _caaController,
                                enabled: canEdit,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: CustomTextField(
                                label: 'Ano de construção',
                                hint: '-',
                                controller: _idadeController,
                                enabled: canEdit,
                                keyboardType: TextInputType.number, 
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),

                        CustomTextField(
                          label: 'Conjunto Estrutural',
                          hint: '-',
                          controller: _conjuntoController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Utilização da estrutura',
                          hint: '-',
                          controller: _utilizacaoController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Tipo de estrutura',
                          hint: '-',
                          controller: _tipoController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Tipologia estrutural',
                          hint: '-',
                          controller: _tipologiaController,
                          enabled: false,
                        ),
                        SizedBox(height: _fieldSpacing),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Latitude',
                                hint: '-',
                                controller: _latController,
                                enabled: canEdit,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                label: 'Longitude',
                                hint: '-',
                                controller: _longController,
                                enabled: canEdit,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'CEP',
                          hint: '-',
                          controller: _cepController,
                          enabled: canEdit,
                        ),
                        SizedBox(height: _fieldSpacing),
                        CustomTextField(
                          label: 'Endereço',
                          hint: '-',
                          controller: _enderecoController,
                          enabled: canEdit,
                        ),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'Cidade',
                                hint: '-',
                                controller: _cidadeController,
                                enabled: canEdit,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                label: 'Número',
                                hint: '-',
                                controller: _numeroController,
                                enabled: canEdit,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _fieldSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                label: 'País',
                                hint: '-',
                                controller: _paisController,
                                enabled: canEdit,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                label: 'UF',
                                hint: '-',
                                controller: _ufController,
                                enabled: canEdit,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 🔥 TRUQUE DE MESTRE: Tira o mapa da tela enquanto o teclado anima!
                        isKeyboardOpen
                            ? Container(
                                height: 150, 
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.inputBorder),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Mapa oculto durante a digitação',
                                    style: TextStyle(color: AppColors.hintText, fontSize: 13),
                                  ),
                                ),
                              )
                            : RepaintBoundary(
                                child: MapaPreviewWidget(
                                  key: const ValueKey('mapa_preview_fixo'),
                                  latitude: latAtual,
                                  longitude: longAtual,
                                ),
                              ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}