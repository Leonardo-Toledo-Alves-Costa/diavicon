import 'dart:convert';
import 'dart:io';
import 'package:diavicon/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../../core/widgets/custom_text_button.dart';
import '../../empresa/providers/empresa_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/cadastro_draft_utils.dart';
import '../utils/cadastro_draft_store.dart';
import '../utils/auth_error_messages.dart';
import '../../../core/utils/formatters/cnpj_formatter.dart';
import '../../../core/utils/validators/cnpj_validator.dart';
import '../../../core/utils/validators/validators_cadastro.dart';

class EmpresaCadastroScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaCadastroScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaCadastroScreen> createState() =>
      _EmpresaCadastroScreenState();
}

class _EmpresaCadastroScreenState extends ConsumerState<EmpresaCadastroScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cepMask = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  XFile? _fotoEmpresa;

  final _cnpjController = TextEditingController();
  final _nomeFantasiaController = TextEditingController();
  String? _nColaboradores;

  final _cargoController = TextEditingController();
  String? _nivelSelecionado;

  final _cepController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _estadoController = TextEditingController();
  final _paisController = TextEditingController(text: 'Brasil');

  final _siteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();

  // 🔥 Controlos da API de CEP (Agora independentes)
  bool _cepBuscado = false;
  bool _cidadeBloqueada = false;
  bool _ruaBloqueada = false;
  bool _bairroBloqueado = false;
  bool _estadoBloqueado = false;
  bool _carregandoCep = false;

  static const _opcoesColaboradores = [
    '1 - 5',
    '6 - 20',
    '21 - 50',
    '51 - 100',
    '100+',
  ];
  static const _niveisCargo = [
    'Júnior',
    'Pleno',
    'Sênior',
    'Gerente',
    'Diretor',
    'CEO',
  ];

  @override
  void initState() {
    super.initState();
    _cepController.addListener(_ouvinteCep);
    _restaurarDadosPersistidos();
  }

  void _restaurarDadosPersistidos() {
    final rawEmpresa = widget.dadosUsuario['empresa'];
    final empresa = rawEmpresa is Map
        ? Map<String, dynamic>.from(rawEmpresa)
        : <String, dynamic>{};
    String text(Map<String, dynamic> map, String key, [String fallback = '']) {
      return map[key]?.toString() ?? fallback;
    }

    _cnpjController.text = text(empresa, 'cnpj');
    _nomeFantasiaController.text = text(empresa, 'nome');
    _nColaboradores = empresa['colaboradores']?.toString();
    _cargoController.text = text(empresa, 'cargo');
    _nivelSelecionado = empresa['nivel']?.toString();
    // Set this before assigning the masked CEP so the listener does not launch
    // a lookup and overwrite the restored address.
    _cepBuscado = text(empresa, 'cep').replaceAll(RegExp(r'\D'), '').length == 8;
    _cepController.text = text(empresa, 'cep');
    _cidadeController.text = text(empresa, 'cidade');
    _ruaController.text = text(empresa, 'rua');
    _bairroController.text = text(empresa, 'bairro');
    _numeroController.text = text(empresa, 'numero');
    _complementoController.text = text(empresa, 'complemento');
    _estadoController.text = text(empresa, 'estado');
    _paisController.text = text(empresa, 'pais', 'Brasil');
    _siteController.text = text(empresa, 'site');
    _linkedinController.text = text(empresa, 'linkedin');
    _instagramController.text = text(empresa, 'instagram');

    // Prevent the CEP listener from replacing the restored address with an
    // external lookup. If the image was copied to app support by the draft
    // store, it remains selectable after an app restart.
    final fotoPath = empresa['fotoPath']?.toString();
    if (fotoPath != null && fotoPath.isNotEmpty && File(fotoPath).existsSync()) {
      _fotoEmpresa = XFile(fotoPath);
    }
  }

  @override
  void dispose() {
    _cepController.removeListener(_ouvinteCep);
    _cnpjController.dispose();
    _nomeFantasiaController.dispose();
    _cargoController.dispose();
    _cepController.dispose();
    _cidadeController.dispose();
    _ruaController.dispose();
    _bairroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _estadoController.dispose();
    _paisController.dispose();
    _siteController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _selecionarFotoEmpresa() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (img != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: img.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar Logo da Empresa',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Ajustar Logo',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
            aspectRatioLockEnabled: true,
            resetButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _fotoEmpresa = XFile(croppedFile.path);
        });
      }
    }
  }

  void _mostrarAviso(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _ouvinteCep() {
    final apenasNumeros = _cepController.text.replaceAll(RegExp(r'\D'), '');

    if (apenasNumeros.length == 8 && !_cepBuscado && !_carregandoCep) {
      _buscarCep(apenasNumeros);
    }

    // Se apagar o CEP, libera tudo
    if (apenasNumeros.isEmpty && _cepBuscado) {
      setState(() {
        _cepBuscado = false;
        _cidadeBloqueada = false;
        _ruaBloqueada = false;
        _bairroBloqueado = false;
        _estadoBloqueado = false;

        _cidadeController.clear();
        _ruaController.clear();
        _bairroController.clear();
        _estadoController.clear();
      });
    }
  }

  Future<void> _buscarCep(String cep) async {
    setState(() => _carregandoCep = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);

        if (dados.containsKey('erro')) {
          _mostrarAviso('CEP não encontrado ou inválido!', Colors.red);
          setState(() {
            _cepBuscado = false;
            _carregandoCep = false;
          });
          return;
        }

        setState(() {
          final localidade = dados['localidade'] ?? '';
          final logradouro = dados['logradouro'] ?? '';
          final bairro = dados['bairro'] ?? '';
          final uf = dados['uf'] ?? '';

          _cidadeController.text = localidade;
          _ruaController.text = logradouro;
          _bairroController.text = bairro;
          _estadoController.text = uf;
          _paisController.text = 'Brasil';

          _cepBuscado = true;

          // 🔥 INTELEGÊNCIA DO CEP: Só bloqueia o campo se a API realmente retornou o dado!
          // Se vier em branco (vazio), a variável assume 'false' e o campo fica editável.
          _cidadeBloqueada = localidade.toString().trim().isNotEmpty;
          _ruaBloqueada = logradouro.toString().trim().isNotEmpty;
          _bairroBloqueado = bairro.toString().trim().isNotEmpty;
          _estadoBloqueado = uf.toString().trim().isNotEmpty;

          _carregandoCep = false;
        });

        _mostrarAviso('Endereço comercial carregado!', Colors.green);
      } else {
        _mostrarAviso('Erro no servidor da ViaCEP.', Colors.red);
        setState(() => _carregandoCep = false);
      }
    } catch (e) {
      _mostrarAviso('Erro de conexão ao buscar o CEP.', Colors.red);
      setState(() => _carregandoCep = false);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!CadastroDraftUtils.hasEmail(widget.dadosUsuario)) {
      _mostrarAviso(
        'A sessão do cadastro expirou. Volte ao início e tente novamente.',
        Colors.red,
      );
      return;
    }

    final dadosCompletos = {
      ...widget.dadosUsuario,
      'empresa': {
        ...(widget.dadosUsuario['empresa'] is Map
            ? Map<String, dynamic>.from(widget.dadosUsuario['empresa'] as Map)
            : const <String, dynamic>{}),
        'cnpj': _cnpjController.text.trim(),
        'nome': _nomeFantasiaController.text.trim(),
        'colaboradores': _nColaboradores,
        'cargo': _cargoController.text.trim(),
        'nivel': _nivelSelecionado,
        'cep': _cepController.text.trim(),
        'cidade': _cidadeController.text.trim(),
        'rua': _ruaController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'estado': _estadoController.text.trim(),
        'pais': _paisController.text.trim(),
        'site': _siteController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'fotoPath': _fotoEmpresa?.path ??
            (widget.dadosUsuario['empresa'] is Map
                ? (widget.dadosUsuario['empresa'] as Map)['fotoPath']
                : null),
      },
    };

    try {
      final draft = {...dadosCompletos, 'perfil_tipo': 'empresa'};
      await CadastroDraftStore().save(draft);
      ref.read(rascunhoCadastroProvider.notifier).state = draft;

      final cadastroConcluido = await ref
          .read(empresaControllerProvider.notifier)
          .cadastrarEmpresa(dadosCompletos);

      if (!cadastroConcluido) {
        if (mounted) context.go('/confirmar-email');
        return;
      }

      if (mounted) {
        await CadastroDraftStore().clear();
        ref.read(rascunhoCadastroProvider.notifier).state = {};
        ref.read(routerProvider).go('/empresa/bemvinda', extra: dadosCompletos);
      }
    } catch (e) {
      if (mounted) {
        _mostrarAviso(authErrorMessage(e, fallback: 'Erro ao salvar no banco.'), Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(empresaControllerProvider);

    return AuthLayout(
      logoHeight: 120,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                28,
                10,
                28,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StepProgressBar(currentStep: 3, totalSteps: 3),
                  const SizedBox(height: 20),

                  _buildLogoPicker(),
                  const SizedBox(height: 20),

                  const Text(
                    'Cadastre sua empresa',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const _SectionTitle(titulo: 'Dados básicos'),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'CNPJ',
                    hint: '123.456.789-10',
                    isRequired: true,
                    controller: _cnpjController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CnpjFormatter.mask],
                    validator: (val) {
                      if (!CnpjValidator.isValid(val)) {
                        return 'CNPJ inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Nome Fantasia',
                    isRequired: true,
                    hint: 'Ex: Diavicon Engenharia',
                    controller: _nomeFantasiaController,
                    validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Nº Colaboradores',
                    hint: 'Selecione',
                    isRequired: true,
                    valor: _nColaboradores,
                    opcoes: _opcoesColaboradores,
                    onChanged: (val) => setState(() => _nColaboradores = val),
                    validator: (v) => v == null ? 'Obrigatório' : null,
                  ),

                  const SizedBox(height: 24),

                  const _SectionTitle(titulo: 'Seu Cargo'),
                  const Text(
                    'Você terá permissões de administrator automaticamente.',
                    style: TextStyle(fontSize: 11, color: AppColors.greyMedium),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Cargo',
                    isRequired: true,
                    hint: 'Ex: Engenheiro Diagnóstico',
                    controller: _cargoController,
                    validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Nível',
                    hint: 'Selecione seu nível',
                    isRequired: true,
                    valor: _nivelSelecionado,
                    opcoes: _niveisCargo,
                    onChanged: (val) => setState(() => _nivelSelecionado = val),
                    validator: (v) => v == null ? 'Obrigatório' : null,
                  ),

                  const SizedBox(height: 24),

                  const _SectionTitle(titulo: 'Endereço Comercial'),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'CEP',
                    isRequired: true,
                    hint: '00000-000',
                    controller: _cepController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_cepMask],
                    enabled: !_carregandoCep,
                    validator: ValidatorsCadastro.cep,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Cidade',
                    hint: 'Cidade',
                    isRequired: true,
                    controller: _cidadeController,
                    enabled:
                        !_cidadeBloqueada, // 🔥 Usando a variável individual
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Obrigatório'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Rua',
                    hint: 'Logradouro',
                    isRequired: true,
                    controller: _ruaController,
                    enabled: !_ruaBloqueada, // 🔥 Usando a variável individual
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Obrigatório'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: CustomTextField(
                          label: 'Número',
                          isRequired: true,
                          hint: '123',
                          controller: _numeroController,
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              ValidatorsCadastro.obrigatorio(v, 'Inválido'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: CustomTextField(
                          label: 'Bairro',
                          isRequired: true,
                          hint: 'Bairro',
                          controller: _bairroController,
                          enabled:
                              !_bairroBloqueado, // 🔥 Usando a variável individual
                          validator: (v) =>
                              ValidatorsCadastro.obrigatorio(v, 'Obrigatório'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Estado',
                    hint: 'Ex: São Paulo',
                    isRequired: true,
                    controller: _estadoController,
                    enabled:
                        !_estadoBloqueado, // 🔥 Usando a variável individual
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Obrigatório'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Complemento',
                    hint: 'Sala, Andar, etc.',
                    controller: _complementoController,
                  ),

                  const SizedBox(height: 24),

                  const _SectionTitle(titulo: 'Redes Sociais (Opcional)'),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Site',
                    hint: 'www.empresa.com',
                    controller: _siteController,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'LinkedIn',
                    hint: 'linkedin.com/company/...',
                    controller: _linkedinController,
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomTextbutton(
                        text: '<   Voltar',
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 40),
                      CustomButton(
                        text: 'Começar',
                        width: 150,
                        fontSize: 15,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _salvar,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Center(
      child: GestureDetector(
        onTap: _selecionarFotoEmpresa,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: AppColors.greyVeryLight,
              backgroundImage: _fotoEmpresa != null
                  ? FileImage(File(_fotoEmpresa!.path))
                  : null,
              child: _fotoEmpresa == null
                  ? const Icon(
                      Icons.domain,
                      size: 52,
                      color: AppColors.greyLight,
                    )
                  : null,
            ),
            Positioned(
              bottom: 2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1C1C1C),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF1C1C1C),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String titulo;
  const _SectionTitle({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.textDark,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? valor;
  final bool isRequired;
  final List<String> opcoes;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;

  const _DropdownField({
    required this.label,
    required this.hint,
    required this.valor,
    this.isRequired = false,
    required this.opcoes,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: valor,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: AppColors.hintText)),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
          items: opcoes
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
