import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';

class CadastroR0Screen extends StatefulWidget {
  const CadastroR0Screen({super.key});

  @override
  State<CadastroR0Screen> createState() => _CadastroR0ScreenState();
}

class _CadastroR0ScreenState extends State<CadastroR0Screen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _avancar() {
    if (_formKey.currentState!.validate()) {
      context.push(
        '/register/dados',
        extra: {
          'email': _emailController.text.trim(),
          'senha': _senhaController.text.trim(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView( 
          physics: const BouncingScrollPhysics(), 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Crie sua conta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comece sua jornada na DiaViCon',
                  style: TextStyle(color: AppColors.greyMedium, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Campo de E-mail
                CustomTextField(
                  label: 'E-mail',
                  hint: 'exemplo@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    final email = val?.trim() ?? "";
                    if (email.isEmpty) return 'Obrigatório';

                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );

                    if (!emailRegex.hasMatch(email)) {
                      return 'E-mail inválido';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Campo de Senha
                CustomTextField(
                  label: 'Senha',
                  hint: '••••••••',
                  controller: _senhaController,
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Obrigatório';
                    if (val.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Confirmar Senha
                CustomTextField(
                  label: 'Confirmar Senha',
                  hint: '••••••••',
                  controller: _confirmarSenhaController,
                  obscureText: true,
                  validator: (val) {
                    if (val != _senhaController.text) {
                      return 'As senhas não batem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Botão Continuar
                CustomButton(text: 'Continuar', onPressed: _avancar),

                const SizedBox(height: 24),

                // Link para Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Já tem uma conta? '),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Faça login',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40), 
              ],
            ),
          ),
        ),
      ),
    );
  }
}