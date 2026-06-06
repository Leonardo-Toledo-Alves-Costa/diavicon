import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters/formatters_cadastro.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

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

  final _nomeCtrl        = TextEditingController();
  final _sobrenomeCtrl   = TextEditingController();
  final _telefoneCtrl    = TextEditingController();
  final _cepCtrl         = TextEditingController();
  final _cidadeCtrl      = TextEditingController();
  final _ruaCtrl         = TextEditingController();
  final _bairroCtrl      = TextEditingController();
  final _numeroCtrl      = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _estadoCtrl      = TextEditingController();
  final _paisCtrl        = TextEditingController();
  final _formacaoCtrl    = TextEditingController();

  String? _escolaridade;

  @override
  void dispose() {
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

  Future<void> _selecionarFoto() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (img != null) setState(() => _foto = img);
  }

  void _comecar() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/register/perfil', extra: {
      ...widget.dadosCadastro,
      'nome'        : _nomeCtrl.text.trim(),
      'sobrenome'   : _sobrenomeCtrl.text.trim(),
      'telefone'    : _telefoneCtrl.text,
      'cep'         : _cepCtrl.text,
      'cidade'      : _cidadeCtrl.text.trim(),
      'rua'         : _ruaCtrl.text.trim(),
      'bairro'      : _bairroCtrl.text.trim(),
      'numero'      : _numeroCtrl.text.trim(),
      'complemento' : _complementoCtrl.text.trim(),
      'estado'      : _estadoCtrl.text.trim(),
      'pais'        : _paisCtrl.text.trim(),
      'escolaridade': _escolaridade,
      'formacao'    : _formacaoCtrl.text.trim(),
      'fotoPath'    : _foto?.path,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                child: _AvatarPicker(
                  foto: _foto,
                  onTap: _selecionarFoto,
                ),
              ),
              const SizedBox(height: 28),

              // ── Informações Pessoais ─────────────────────────
              const _SectionTitle('Informações Pessoais'),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Nome',
                hint: 'João',
                controller: _nomeCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Sobrenome',
                hint: 'Silva',
                controller: _sobrenomeCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o sobrenome' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Telefone',
                hint: '(31) 9 9191-9191',
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
                hint: '31.333-000',
                controller: _cepCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FormattersCadastro.cep],
                validator: ValidatorsCadastro.cep,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Cidade',
                hint: 'Belo Horizonte',
                controller: _cidadeCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a cidade' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Rua',
                hint: 'Rua Abc',
                controller: _ruaCtrl,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Bairro',
                hint: 'Bairro Xyz',
                controller: _bairroCtrl,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      label: 'Número',
                      hint: '123',
                      controller: _numeroCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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
                controller: _estadoCtrl,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'País',
                hint: 'Brasil',
                controller: _paisCtrl,
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
              const SizedBox(height: 32),

              // ── Ações ────────────────────────────────────────
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Voltar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Começar',
                    onPressed: _comecar,
                  ),
                ],
              ),
            ],
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
            radius: 52,
            backgroundColor: Colors.grey.shade200,
            backgroundImage:
                foto != null ? FileImage(File(foto!.path)) : null,
            child: foto == null
                ? Icon(Icons.person, size: 48, color: Colors.grey.shade400)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, size: 14, color: Colors.white),
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

  const _DropdownEscolaridade({
    required this.value,
    required this.onChanged,
  });

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