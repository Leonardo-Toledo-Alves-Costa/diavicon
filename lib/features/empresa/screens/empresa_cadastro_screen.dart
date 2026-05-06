import 'package:diavicon/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../providers/empresa_provider.dart';

class EmpresaCadastroScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaCadastroScreen({super.key, required this.dadosUsuario});

  @override
  ConsumerState<EmpresaCadastroScreen> createState() =>
      _EmpresaCadastroScreenState();
}

class _EmpresaCadastroScreenState extends ConsumerState<EmpresaCadastroScreen> {
  final _formKey = GlobalKey<FormState>();

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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    // Preparao objeto final que contém TUDO
    final dadosCompletos = {
      ...widget
          .dadosUsuario, // Traz email, senha, nome, sobrenome, telefone e plano_id
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
      // Salva no banco
      await ref
          .read(empresaControllerProvider.notifier)
          .cadastrarEmpresa(dadosCompletos);

      print("✅ BANCO SALVOU! Tentando navegar...");

      // Tenta navegar
      if (mounted) {
        print("🚀 TELA ATIVA! Executando context.go para Bem-vinda...");
        ref.read(routerProvider).go('/empresa/bemvinda', extra: dadosCompletos);
      } else {
        print(
          "❌ ERRO: A tela 'morreu' (unmounted) antes de conseguir navegar.",
        );
      }
    } catch (e) {
      print('=========================================');
      print('🚨 ERRO FATAL AO CRIAR EMPRESA: $e');
      print('=========================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no banco: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(
              seconds: 5,
            ), // Tempo extra pra você conseguir ler
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(empresaControllerProvider);

    return AuthLayout(
      logoHeight: 120,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
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

              // ── SEÇÃO: DADOS BÁSICOS ───────────────────────────────────────
              const _SectionTitle(titulo: 'Dados básicos'),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'CNPJ',
                hint: '00.000.000/0001-00',
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                validator: (val) =>
                    (val?.length ?? 0) < 14 ? 'CNPJ inválido' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Nome Fantasia',
                hint: 'Ex: Diavicon Engenharia',
                controller: _nomeFantasiaController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              _DropdownField(
                label: 'Nº Colaboradores',
                hint: 'Selecione',
                valor: _nColaboradores,
                opcoes: _opcoesColaboradores,
                onChanged: (val) => setState(() => _nColaboradores = val),
              ),

              const SizedBox(height: 24),

              const _SectionTitle(titulo: 'Seu Cargo'),
              const Text(
                'Você terá permissões de administrador automaticamente.',
                style: TextStyle(fontSize: 11, color: AppColors.greyMedium),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Cargo',
                hint: 'Ex: Engenheiro Diagnóstico',
                controller: _cargoController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              _DropdownField(
                label: 'Nível',
                hint: 'Selecione seu nível',
                valor: _nivelSelecionado,
                opcoes: _niveisCargo,
                onChanged: (val) => setState(() => _nivelSelecionado = val),
              ),

              const SizedBox(height: 24),

              const _SectionTitle(titulo: 'Endereço Comercial'),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'CEP',
                hint: '00000-000',
                controller: _cepController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Cidade',
                hint: 'Cidade',
                controller: _cidadeController,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Rua',
                hint: 'Logradouro',
                controller: _ruaController,
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: CustomTextField(
                      label: 'Bairro',
                      hint: 'Bairro',
                      controller: _bairroController,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomTextField(
                label: 'Estado',
                hint: 'Ex: São Paulo',
                controller: _estadoController,
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

              const SizedBox(height: 32),

              CustomButton(
                text: 'Começar',
                isLoading: isLoading,
                onPressed: isLoading ? null : _salvar,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
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

  Widget _buildLogoPicker() {
    return Center(
      child: GestureDetector(
        onTap: () {}, // Lógica de imagem aqui futuramente
        child: Stack(
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.greyVeryLight,
              child: const Icon(
                Icons.domain,
                size: 40,
                color: AppColors.greyLight,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.edit, size: 14, color: Colors.white),
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

//widgets internos
class _DropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? valor;
  final List<String> opcoes;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.hint,
    required this.valor,
    required this.opcoes,
    required this.onChanged,
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
          value: valor,
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
        ),
      ],
    );
  }
}
