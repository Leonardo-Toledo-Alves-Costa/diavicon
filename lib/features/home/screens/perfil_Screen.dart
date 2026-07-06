import 'dart:convert';
import 'dart:io';

import 'package:diavicon/core/constants/app_text_styles.dart';
import 'package:diavicon/core/utils/formatters/cep_formatter.dart';
import 'package:diavicon/features/home/screens/perfil_drawer.dart';
import 'package:diavicon/features/home/screens/perfil_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters/formatters_cadastro.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_text_button.dart';

const _escolaridades = <String>[
  'Ensino Médio',
  'Graduação',
  'Especialização',
  'Mestrado',
  'Doutorado',
];

class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> dadosCadastro;

  const PerfilScreen({super.key, required this.dadosCadastro});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  XFile? _foto;

  final _nomeCtrl = TextEditingController();
  final _sobrenomeCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ruaCtrl = TextEditingController();
  final _bairroCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();
  final _formacaoCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();

  String? _escolaridade;

  // 🔥 Controlos de estado para a API de CEP (Agora independentes)
  bool _cepBuscado = false;
  bool _cidadeBloqueada = false;
  bool _ruaBloqueada = false;
  bool _bairroBloqueado = false;
  bool _estadoBloqueado = false;
  bool _carregandoCep = false;

  @override
  void initState() {
    super.initState();
    _cepCtrl.addListener(_ouvinteCep);
  }

  @override
  void dispose() {
    _cepCtrl.removeListener(_ouvinteCep);
    _nomeCtrl.dispose();
    _sobrenomeCtrl.dispose();
    _telefoneCtrl.dispose();
    _cepCtrl.dispose();
    _cidadeCtrl.dispose();
    _ruaCtrl.dispose();
    _bairroCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _estadoCtrl.dispose();
    _paisCtrl.dispose();
    _formacaoCtrl.dispose();
    _linkedinCtrl.dispose();
    _instagramCtrl.dispose();
    _siteCtrl.dispose();
    super.dispose();
  }

  void _ouvinteCep() {
    final apenasNumeros = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');

    if (apenasNumeros.length == 8 && !_cepBuscado && !_carregandoCep) {
      _buscarCep(apenasNumeros);
    }

    if (apenasNumeros.isEmpty && _cepBuscado) {
      setState(() {
        _cepBuscado = false;
        _cidadeBloqueada = false;
        _ruaBloqueada = false;
        _bairroBloqueado = false;
        _estadoBloqueado = false;

        _cidadeCtrl.clear();
        _ruaCtrl.clear();
        _bairroCtrl.clear();
        _estadoCtrl.clear();
        _paisCtrl.clear();
      });
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

          _cidadeCtrl.text = localidade;
          _ruaCtrl.text = logradouro;
          _bairroCtrl.text = bairro;
          _estadoCtrl.text = uf;
          _paisCtrl.text = 'Brasil';

          _cepBuscado = true;
          // 🔥 A inteligência entra aqui: só bloqueia se tiver vindo preenchido da API!
          _cidadeBloqueada = localidade.isNotEmpty;
          _ruaBloqueada = logradouro.isNotEmpty;
          _bairroBloqueado = bairro.isNotEmpty;
          _estadoBloqueado = uf.isNotEmpty;

          _carregandoCep = false;
        });

        _mostrarAviso('Endereço preenchido com sucesso!', Colors.green);
      } else {
        _mostrarAviso('Erro no servidor da ViaCEP.', Colors.red);
        setState(() => _carregandoCep = false);
      }
    } catch (e) {
      _mostrarAviso('Erro de conexão ao buscar o CEP.', Colors.red);
      setState(() => _carregandoCep = false);
    }
  }

  Future<void> _selecionarFoto() async {
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
            toolbarTitle: 'Ajustar Foto',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Ajustar Foto',
            cancelButtonTitle: 'Cancelar',
            doneButtonTitle: 'Concluir',
            aspectRatioLockEnabled: true,
            resetButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _foto = XFile(croppedFile.path);
        });
      }
    }
  }

  void _comecar() {
    if (!_formKey.currentState!.validate()) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Perfil'),
          const SizedBox(height: 35),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const Text(
                                'Perfil',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3E3E3D),
                                  fontFamily: 'Lato',
                                ),
                              ),
                              const SizedBox(height: 14),
                              _AvatarPicker(
                                foto: _foto,
                                onTap: _selecionarFoto,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _SectionCard(
                          title: 'Dados pessoais',
                          initiallyExpanded: true,
                          children: [
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Nome',
                              hint: 'João',
                              isRequired: true,
                              controller: _nomeCtrl,
                              validator: (v) => ValidatorsCadastro.nome(v, 'nome'),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Sobrenome',
                              isRequired: true,
                              hint: 'Silva',
                              controller: _sobrenomeCtrl,
                              validator: (v) => ValidatorsCadastro.nome(v, 'sobrenome'),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Telefone',
                              hint: '(31) 9 9191-9191',
                              isRequired: true,
                              controller: _telefoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FormattersCadastro.telefone],
                              validator: ValidatorsCadastro.telefone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Endereço',
                          initiallyExpanded: true,
                          children: [
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'CEP',
                              isRequired: true,
                              hint: '31333-000',
                              controller: _cepCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CepFormatter.mask],
                              validator: ValidatorsCadastro.cep,
                              enabled: !_carregandoCep,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Cidade',
                              hint: 'Belo Horizonte',
                              isRequired: true,
                              controller: _cidadeCtrl,
                              enabled: !_cidadeBloqueada,
                              validator: (v) => ValidatorsCadastro.obrigatorio(
                                v,
                                'Informe a cidade',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Rua',
                              hint: 'Rua Abc',
                              isRequired: true,
                              controller: _ruaCtrl,
                              enabled: !_ruaBloqueada,
                              validator: (v) => ValidatorsCadastro.obrigatorio(
                                v,
                                'Informe a rua',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Bairro',
                              hint: 'Bairro Xyz',
                              isRequired: true,
                              controller: _bairroCtrl,
                              enabled: !_bairroBloqueado,
                              validator: (v) => ValidatorsCadastro.obrigatorio(
                                v,
                                'Informe o bairro',
                              ),
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
                                    controller: _numeroCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) => ValidatorsCadastro.obrigatorio(
                                      v,
                                      'Inválido',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: CustomTextField(
                                    label: 'Complemento',
                                    hint: 'Apto 123',
                                    controller: _complementoCtrl,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Estado',
                              hint: 'Minas Gerais',
                              isRequired: true,
                              controller: _estadoCtrl,
                              enabled: !_estadoBloqueado,
                              validator: (v) => ValidatorsCadastro.obrigatorio(
                                v,
                                'Informe o estado',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'País',
                              isRequired: true,
                              hint: 'Brasil',
                              controller: _paisCtrl,
                              enabled: false,
                              validator: (v) => ValidatorsCadastro.obrigatorio(
                                v,
                                'Informe o país',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Título e escolaridade',
                          initiallyExpanded: true,
                          children: [
                            const SizedBox(height: 12),
                            _DropdownEscolaridade(
                              value: _escolaridade,
                              onChanged: (v) => setState(() => _escolaridade = v),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Formação',
                              hint: 'Engenharia Civil',
                              controller: _formacaoCtrl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Redes sociais',
                          initiallyExpanded: true,
                          children: [
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'LinkedIn',
                              hint: 'linkedin.com/in/seu-perfil',
                              controller: _linkedinCtrl,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Instagram',
                              hint: 'instagram.com/seu-perfil',
                              controller: _instagramCtrl,
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              label: 'Website',
                              hint: 'www.suaempresa.com',
                              controller: _siteCtrl,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomTextbutton(
                              text: '<   Voltar',
                              onPressed: () => context.pop(),
                            ),
                            const SizedBox(width: 40),
                            CustomButton(
                              text: 'Salvar',
                              width: 150,
                              fontSize: 15,
                              onPressed: _comecar,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F8F8),
      borderRadius: BorderRadius.circular(16),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          collapsedBackgroundColor: const Color(0xFFF8F8F8),
          backgroundColor: const Color(0xFFF8F8F8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E5E5)),
          ),
          iconColor: const Color(0xFF3E3E3D),
          collapsedIconColor: const Color(0xFF3E3E3D),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E3E3D),
              fontFamily: 'Lato',
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final XFile? foto;
  final VoidCallback onTap;

  const _AvatarPicker({required this.foto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: foto != null ? FileImage(File(foto!.path)) : null,
            child: foto == null
                ? Icon(Icons.person, size: 52, color: Colors.grey.shade400)
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
                border: Border.all(color: const Color(0xFF1C1C1C), width: 1.5),
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
    );
  }
}

class _DropdownEscolaridade extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DropdownEscolaridade({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.error),
        ),
      ),
      hint: const Text('Escolaridade'),
      items: _escolaridades
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) =>
          ValidatorsCadastro.dropdown(v, mensagem: 'Selecione a escolaridade'),
    );
  }
}
