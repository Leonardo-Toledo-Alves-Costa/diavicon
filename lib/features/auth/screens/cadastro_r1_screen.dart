import 'dart:convert';
import 'dart:io';

import 'package:diavicon/core/constants/app_text_styles.dart';
import 'package:diavicon/core/utils/formatters/cep_formatter.dart';
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

class CadastroR1Screen extends StatefulWidget {
  final Map<String, dynamic> dadosCadastro;

  const CadastroR1Screen({super.key, required this.dadosCadastro});

  @override
  State<CadastroR1Screen> createState() => _CadastroR1ScreenState();
}

class _CadastroR1ScreenState extends State<CadastroR1Screen> {
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

  String? _escolaridade;

  // Controlo de estado para a API de CEP
  bool _enderecoBloqueado = false;
  bool _carregandoCep = false;

  @override
  void initState() {
    super.initState();
    // Ouve as alterações do CEP em tempo real
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
    super.dispose();
  }

  void _ouvinteCep() {
    final apenasNumeros = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');

    // Dispara a busca automaticamente ao atingir 8 dígitos
    if (apenasNumeros.length == 8 && !_enderecoBloqueado && !_carregandoCep) {
      _buscarCep(apenasNumeros);
    }

    // Se o utilizador apagar o CEP, liberta os campos para edição manual
    if (apenasNumeros.isEmpty && _enderecoBloqueado) {
      setState(() {
        _enderecoBloqueado = false;
        _cidadeCtrl.clear();
        _ruaCtrl.clear();
        _bairroCtrl.clear();
        _estadoCtrl.clear();
        _paisCtrl.clear();
      });
    }
  }

  //Função auxiliar que garante que o aviso aparece no lugar certo!
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
        behavior: SnackBarBehavior.floating, // Faz flutuar
        margin: const EdgeInsets.all(
          20,
        ), // O Flutter já cuida de subir isso acima do teclado!
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

        //  containsKey('erro') ignora se é texto ou booleano, só vê se a palavra "erro" veio da API.
        if (dados.containsKey('erro')) {
          _mostrarAviso('CEP não encontrado ou inválido!', Colors.red);
          setState(() {
            _enderecoBloqueado = false;
            _carregandoCep = false;
          });
          return;
        }

        // Se deu tudo certo, preenche os campos
        setState(() {
          _cidadeCtrl.text = dados['localidade'] ?? '';
          _ruaCtrl.text = dados['logradouro'] ?? '';
          _bairroCtrl.text = dados['bairro'] ?? '';
          _estadoCtrl.text = dados['uf'] ?? '';
          _paisCtrl.text = 'Brasil';

          _enderecoBloqueado = true;
          _carregandoCep = false;
        });

        // Aviso verde de sucesso!
        _mostrarAviso('Endereço preenchido com sucesso!', Colors.green);
      } else {
        // Se a API retornar código 400 ou 500
        _mostrarAviso('Erro no servidor da ViaCEP.', Colors.red);
        setState(() => _carregandoCep = false);
      }
    } catch (e) {
      // Se não tiver internet
      _mostrarAviso('Erro de conexão ao buscar o CEP.', Colors.red);
      setState(() => _carregandoCep = false);
    }
  }

  Future<void> _selecionarFoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth:
          1024,
      maxHeight: 1024,
    );

    if (img != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: img.path,
        aspectRatio: const CropAspectRatio(
          ratioX: 1,
          ratioY: 1,
        ), 
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
    context.push(
      '/register/perfil',
      extra: {
        ...widget.dadosCadastro,
        'nome': _nomeCtrl.text.trim(),
        'sobrenome': _sobrenomeCtrl.text.trim(),
        'telefone': _telefoneCtrl.text,
        'cep': _cepCtrl.text,
        'cidade': _cidadeCtrl.text.trim(),
        'rua': _ruaCtrl.text.trim(),
        'bairro': _bairroCtrl.text.trim(),
        'numero': _numeroCtrl.text.trim(),
        'complemento': _complementoCtrl.text.trim(),
        'estado': _estadoCtrl.text.trim(),
        'pais': _paisCtrl.text.trim(),
        'escolaridade': _escolaridade,
        'formacao': _formacaoCtrl.text.trim(),
        'fotoPath': _foto?.path,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              28,
              24,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seja Bem Vindo à',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1C),
                      height: 1.25,
                    ),
                  ),
                  const Text(
                    'DiaViCon',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: _AvatarPicker(foto: _foto, onTap: _selecionarFoto),
                  ),
                  const SizedBox(height: 28),

                  // ── Informações Pessoais ─────────────────────────
                  const _SectionTitle('Informações Pessoais'),
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
                  const SizedBox(height: 28),

                  // ── Endereço ────────────────────────────────────
                  const _SectionTitle('Endereço'),
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
                    enabled: !_enderecoBloqueado,
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Informe a cidade'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Rua',
                    hint: 'Rua Abc',
                    isRequired: true,
                    controller: _ruaCtrl,
                    enabled: !_enderecoBloqueado,
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Informe a rua'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Bairro',
                    hint: 'Bairro Xyz',
                    isRequired: true,
                    controller: _bairroCtrl,
                    enabled: !_enderecoBloqueado,
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Informe o bairro'),
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
                          validator: (v) =>
                              ValidatorsCadastro.obrigatorio(v, 'Inválido'),
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
                    enabled: !_enderecoBloqueado,
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Informe o estado'),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'País',
                    isRequired: true,
                    hint: 'Brasil',
                    controller: _paisCtrl,
                    enabled: !_enderecoBloqueado,
                    validator: (v) =>
                        ValidatorsCadastro.obrigatorio(v, 'Informe o país'),
                  ),
                  const SizedBox(height: 28),

                  // ── Título e Escolaridade ────────────────────────
                  const _SectionTitle('Título e Escolaridade'),
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
                  const SizedBox(height: 40),

                  // ── Ações ────────────────────────────────────────
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────

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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C1C1C),
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
