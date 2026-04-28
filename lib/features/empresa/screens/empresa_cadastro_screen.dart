import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

import '../../../core/widgets/custom_text_field.dart';

import '../../../core/widgets/custom_button.dart';

import '../../../core/widgets/auth_layout.dart';

import '../../../core/widgets/step_progress_bar.dart';

import '../providers/empresa_provider.dart';

/// Formulário completo de cadastro da empresa.

/// Integrado com Supabase via EmpresaController.

/// Rota: /empresa/cadastro

class EmpresaCadastroScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaCadastroScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaCadastroScreen> createState() =>
      _EmpresaCadastroScreenState();
}

class _EmpresaCadastroScreenState extends ConsumerState<EmpresaCadastroScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Dados básicos ──────────────────────────────────────────────────────────

  final _cnpjController = TextEditingController();

  final _nomeFantasiaController = TextEditingController();

  String? _nColaboradores;

  // ── Cargo ──────────────────────────────────────────────────────────────────

  final _cargoController = TextEditingController();

  String? _nivelSelecionado;

  // ── Endereço ───────────────────────────────────────────────────────────────

  final _cepController = TextEditingController();

  final _cidadeController = TextEditingController();

  final _ruaController = TextEditingController();

  final _bairroController = TextEditingController();

  final _numeroController = TextEditingController();

  final _complementoController = TextEditingController();

  final _estadoController = TextEditingController();

  final _paisController = TextEditingController(text: 'Brasil');

  // ── Redes Sociais ──────────────────────────────────────────────────────────

  final _siteController = TextEditingController();

  final _linkedinController = TextEditingController();

  final _instagramController = TextEditingController();

  static const _opcoesColaboradores = [
    '1 - 5',
    '6 - 20',
    '21 - 50',
    '51 - 100',
    '100+',
  ];

  static const _niveisCarrgo = [
    'Júnior',
    'Pleno',
    'Sênior',
    'Gerente',
    'Diretor',
    'CEO',
  ];

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(empresaControllerProvider);

    return AuthLayout(
      logoHeight: 140,

      child: Form(
        key: _formKey,

        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              const StepProgressBar(currentStep: 3, totalSteps: 3),

              const SizedBox(height: 20),

              // ── Logo ──────────────────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _selecionarLogo,

                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,

                        backgroundColor: AppColors.greyVeryLight,

                        child: Image.asset(
                          'assets/images/empresa.png',

                          width: 56,

                          errorBuilder: (_, _, _) => const Icon(
                            Icons.domain,

                            size: 44,

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

              const Text(
                'Cadastre sua empresa',

                style: TextStyle(
                  fontSize: 22,

                  fontWeight: FontWeight.w900,

                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 20),

              // ── Dados básicos ─────────────────────────────────────────────
              const _SectionTitle(titulo: 'Dados básicos'),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'CNPJ',

                hint: '90.336.515/0001-50',

                controller: _cnpjController,

                keyboardType: TextInputType.number,

                validator: (val) {
                  if (val == null || val.isEmpty) return 'Obrigatório';

                  final digits = val.replaceAll(RegExp(r'\D'), '');

                  if (digits.length != 14) return 'CNPJ inválido';

                  return null;
                },
              ),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'Nome Fantasia',

                hint: 'Empresa S.A.',

                controller: _nomeFantasiaController,

                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),

              const SizedBox(height: 12),

              _DropdownField(
                label: 'Nº Colaboradores',

                hint: 'Nº Colaboradores',

                valor: _nColaboradores,

                opcoes: _opcoesColaboradores,

                validator: (val) =>
                    val == null ? 'Selecione o número de colaboradores' : null,

                onChanged: (val) => setState(() => _nColaboradores = val),
              ),

              const SizedBox(height: 20),

              // ── Cargo ─────────────────────────────────────────────────────
              const _SectionTitle(titulo: 'Seu Cargo'),

              const SizedBox(height: 4),

              const Text(
                'Ao cadastrar a empresa você terá automaticamente todas as permissões de acesso da empresa',

                style: TextStyle(fontSize: 11, color: AppColors.greyMedium),
              ),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'Cargo',

                hint: 'Gerente',

                controller: _cargoController,

                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),

              const SizedBox(height: 12),

              _DropdownField(
                label: 'Nível',

                hint: 'Nível',

                valor: _nivelSelecionado,

                opcoes: _niveisCarrgo,

                validator: (val) => val == null ? 'Selecione o nível' : null,

                onChanged: (val) => setState(() => _nivelSelecionado = val),
              ),

              const SizedBox(height: 20),

              // ── Endereço ──────────────────────────────────────────────────
              const _SectionTitle(titulo: 'Endereço'),

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

                hint: '31.333-000',

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

                      validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
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

              // ── Redes Sociais ─────────────────────────────────────────────
              const _SectionTitle(titulo: 'Redes Sociais'),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'Site',

                hint: 'www.empresa.com.br',

                controller: _siteController,

                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'LinkedIn',

                hint: 'www.linkedin.com/company/empresa',

                controller: _linkedinController,

                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 12),

              CustomTextField(
                label: 'Instagram',

                hint: 'www.instagram.com/empresa',

                controller: _instagramController,

                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 30),

              CustomButton(
                text: 'Começar',

                isLoading: isLoading,

                onPressed: isLoading ? null : _salvar,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () =>
                    context.go('/empresa/planos', extra: widget.dadosUsuario),

                child: const Text(
                  '< Voltar',

                  style: TextStyle(color: AppColors.greyMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final dadosCompletos = {
      ...widget.dadosUsuario,

      'empresa': {
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
      },
    };

    try {
      await ref
          .read(empresaControllerProvider.notifier)
          .cadastrarEmpresa(dadosCompletos);

      if (mounted) {
        context.go('/empresa/bemvinda', extra: dadosCompletos);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    }
  }

  void _selecionarLogo() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Seleção de logo em breve.')));
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

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

  final List<String> opcoes;

  final String? Function(String?)? validator;

  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,

    required this.hint,

    required this.valor,

    required this.opcoes,

    required this.onChanged,

    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,

          style: const TextStyle(
            fontSize: 14,

            fontWeight: FontWeight.bold,

            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 8),

        DropdownButtonFormField<String>(
          initialValue: valor,

          hint: Text(hint, style: const TextStyle(color: AppColors.hintText)),

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
