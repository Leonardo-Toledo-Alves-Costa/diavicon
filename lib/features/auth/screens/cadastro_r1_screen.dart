import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/auth_layout.dart';

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

  // ── Controllers Dados Pessoais ─────────────────────────────────────────────
  final _nomeController = TextEditingController();
  final _sobrenomeController = TextEditingController();
  final _telefoneController = TextEditingController();

  // ── Controllers Endereço ───────────────────────────────────────────────────
  final _cepController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ruaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _estadoController = TextEditingController();
  final _paisController = TextEditingController(text: 'Brasil');

  // ── Escolaridade ──────────────────────────────────────────────────────────
  final _formacaoController = TextEditingController();
  String? _escolaridadeSelecionada;

  final List<String> _escolaridades = [
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

  void _avancar() {
    if (!_formKey.currentState!.validate()) return;
    
    // Passa o "pacotão" de dados para a R2 (Perfil)
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

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      logoHeight: 120,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitle(),
              const SizedBox(height: 24),
              
              // --- Foto de Perfil ---
              _buildPhotoPicker(),
              const SizedBox(height: 32),

              // --- Seção: Pessoal ---
              _SectionTitle(titulo: 'Informações Pessoais'),
              const SizedBox(height: 12),
              CustomTextField(label: 'Nome', hint: 'João', controller: _nomeController),
              const SizedBox(height: 12),
              CustomTextField(label: 'Sobrenome', hint: 'Silva', controller: _sobrenomeController),
              const SizedBox(height: 12),
              CustomTextField(label: 'Telefone', hint: '(31) 9 9191-9191', controller: _telefoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 32),

              // --- Seção: Endereço ---
              _SectionTitle(titulo: 'Endereço'),
              const SizedBox(height: 12),
              CustomTextField(label: 'CEP', hint: '31333-000', controller: _cepController),
              const SizedBox(height: 12),
              CustomTextField(label: 'Cidade', hint: 'Belo Horizonte', controller: _cidadeController),
              const SizedBox(height: 12),
              CustomTextField(label: 'Rua', hint: 'Rua das Flores', controller: _ruaController),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: CustomTextField(label: 'Nº', hint: '123', controller: _numeroController)),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: CustomTextField(label: 'Complemento', hint: 'Apto 10', controller: _complementoController)),
                ],
              ),
              const SizedBox(height: 32),

              // --- Seção: Acadêmico ---
              _SectionTitle(titulo: 'Título e Escolaridade'),
              const SizedBox(height: 12),
              _buildDropdownEscolaridade(),
              const SizedBox(height: 12),
              CustomTextField(label: 'Formação', hint: 'Engenharia Civil', controller: _formacaoController),
              
              const SizedBox(height: 40),

              // --- Botões ---
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('< Voltar', style: TextStyle(color: AppColors.greyMedium)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _avancar,
                      child: const Text('Próximo', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Widgets Auxiliares internos para manter o código limpo
  Widget _buildTitle() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
        children: [
          TextSpan(text: 'Seja Bem Vindo à\n'),
          TextSpan(text: 'DiaViCon', style: TextStyle(color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: Stack(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.greyVeryLight,
            backgroundImage: AssetImage('assets/images/user.png'),
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
    );
  }

  Widget _buildDropdownEscolaridade() {
    return DropdownButtonFormField<String>(
      value: _escolaridadeSelecionada,
      hint: const Text('Selecione a Escolaridade'),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _escolaridades.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (val) => setState(() => _escolaridadeSelecionada = val),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark),
    );
  }
}