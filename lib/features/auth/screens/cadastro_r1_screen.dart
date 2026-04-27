import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/auth_layout.dart';

/// CadastroR1 — Foto, dados pessoais, endereço, título e escolaridade.
/// Rota: /register/dados
class CadastroR1Screen extends ConsumerStatefulWidget {
  final String email;
  final String senha;

  const CadastroR1Screen({
    super.key,
    required this.email,
    required this.senha,
  });

  @override
  ConsumerState<CadastroR1Screen> createState() => _CadastroR1ScreenState();
}

class _CadastroR1ScreenState extends ConsumerState<CadastroR1Screen> {
  final _formKey = GlobalKey<FormState>();

  // ── Dados pessoais ─────────────────────────────────────────────────────────
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();

  // ── Endereço ───────────────────────────────────────────────────────────────
  final _cepController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _estadoController = TextEditingController();
  final _paisController = TextEditingController(text: 'Brasil');

  // ── Título e Escolaridade ──────────────────────────────────────────────────
  final _formacaoController = TextEditingController();
  String? _escolaridadeSelecionada;

  static const List<String> _escolaridades = [
    'Ensino Médio',
    'Técnico',
    'Graduação',
    'Especialização',
    'Mestrado',
    'Doutorado',
    'Pós-Doutorado',
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _telefoneController.dispose();
    _cepController.dispose();
    _cidadeController.dispose();
    _ruaController.dispose();
    _bairroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _estadoController.dispose();
    _paisController.dispose();
    _formacaoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      logoHeight: 140,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Título ─────────────────────────────────────────────────────
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                  children: [
                    TextSpan(text: 'Seja Bem Vindo à\n'),
                    TextSpan(
                      text: 'DiaViCon',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Foto de Perfil ─────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _selecionarFoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.greyVeryLight,
                        child: Image.asset(
                          'assets/images/user.png',
                          width: 56,
                          height: 56,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 48,
                            color: AppColors.greyLight,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Informações Pessoais ───────────────────────────────────────
              _SectionTitle(titulo: 'Informações Pessoais'),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Nome',
                hint: 'João',
                controller: _nomeController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Sobrenome',
                hint: 'Silva',
                controller: _sobrenomeController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Telefone',
                hint: '(31) 9 9191-9191',
                controller: _telefoneController,
                keyboardType: TextInputType.phone,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 20),

              // ── Endereço ───────────────────────────────────────────────────
              _SectionTitle(titulo: 'Endereço'),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'CEP',
                hint: '31.333-000',
                controller: _cepController,
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Cidade',
                hint: 'Belo Horizonte',
                controller: _cidadeController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Rua',
                hint: 'Rua Abc',
                controller: _ruaController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Bairro',
                hint: 'Bairro Xyz',
                controller: _bairroController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CustomTextField(
                      label: 'Número',
                      hint: '123',
                      controller: _numeroController,
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          val!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: CustomTextField(
                      label: 'Complemento',
                      hint: 'Apto123',
                      controller: _complementoController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Estado',
                hint: 'Minas Gerais',
                controller: _estadoController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'País',
                hint: 'Brasil',
                controller: _paisController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 20),

              // ── Título e Escolaridade ──────────────────────────────────────
              _SectionTitle(titulo: 'Título e Escolaridade'),
              const SizedBox(height: 12),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Escolaridade',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _escolaridadeSelecionada,
                    hint: const Text(
                      'Escolaridade',
                      style: TextStyle(color: AppColors.hintText),
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    items: _escolaridades
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _escolaridadeSelecionada = val),
                    validator: (val) =>
                        val == null ? 'Selecione a escolaridade' : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: 'Formação',
                hint: 'Ex: Engenharia Civil',
                controller: _formacaoController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 30),

              // ── Botões ─────────────────────────────────────────────────────
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text(
                      '< Voltar',
                      style: TextStyle(color: AppColors.greyMedium),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _avancar,
                      child: const Text(
                        'Começar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _avancar() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/register/perfil', extra: {
      'email': widget.email,
      'senha': widget.senha,
      'nome': _nomeController.text.trim(),
      'sobrenome': _sobrenomeController.text.trim(),
      'telefone': _telefoneController.text.trim(),
      'cep': _cepController.text.trim(),
      'cidade': _cidadeController.text.trim(),
      'rua': _ruaController.text.trim(),
      'bairro': _bairroController.text.trim(),
      'numero': _numeroController.text.trim(),
      'complemento': _complementoController.text.trim(),
      'estado': _estadoController.text.trim(),
      'pais': _paisController.text.trim(),
      'escolaridade': _escolaridadeSelecionada,
      'formacao': _formacaoController.text.trim(),
    });
  }

  void _selecionarFoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seleção de foto em breve.')),
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