import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/utils/validators/validators_cadastro.dart';

/// CadastroR0 — E-mail, senha e confirmação.
/// Rota: /register
class CadastroR0Screen extends ConsumerStatefulWidget {
  const CadastroR0Screen({super.key});

  @override
  ConsumerState<CadastroR0Screen> createState() => _CadastroR0ScreenState();
}

class _CadastroR0ScreenState extends ConsumerState<CadastroR0Screen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _ocultarSenha = true;
  bool _ocultarConfirmar = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 35, 28, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Título ────────────────────────────────────────────────────
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                  children: [
                    TextSpan(text: 'Seja Bem Vindo à\n'),
                    TextSpan(
                      text: 'DIAVICON!',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vamos iniciar o seu cadastro',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 30),

              // ── E-mail ────────────────────────────────────────────────────
              CustomTextField(
                label: 'Seu melhor e-mail',
                hint: 'seuemail@email.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: ValidatorsCadastro.email,
              ),
              const SizedBox(height: 14),

              // ── Senha ─────────────────────────────────────────────────────
              CustomTextField(
                label: 'Senha',
                hint: 'Sua senha',
                controller: _senhaController,
                obscureText: _ocultarSenha,
                suffixIcon: _buildEyeIcon(
                  ocultar: _ocultarSenha,
                  onTap: () =>
                      setState(() => _ocultarSenha = !_ocultarSenha),
                ),
                validator: ValidatorsCadastro.senha,
              ),
              const SizedBox(height: 14),

              // ── Confirmar Senha ───────────────────────────────────────────
              CustomTextField(
                label: 'Confirme a senha',
                hint: 'Sua senha',
                controller: _confirmarController,
                obscureText: _ocultarConfirmar,
                suffixIcon: _buildEyeIcon(
                  ocultar: _ocultarConfirmar,
                  onTap: () => setState(
                      () => _ocultarConfirmar = !_ocultarConfirmar),
                ),
                validator: (val) => ValidatorsCadastro.confirmarSenha(
                  val,
                  _senhaController.text,
                ),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Avançar',
                onPressed: _avancar,
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Já possui uma conta? ',
                    style: TextStyle(
                        color: AppColors.greyMedium, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Entrar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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

  Widget _buildEyeIcon({
    required bool ocultar,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(
        ocultar ? Icons.visibility_off : Icons.visibility,
        size: 20,
        color: AppColors.greyMedium,
      ),
      onPressed: onTap,
    );
  }

  void _avancar() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/register/dados', extra: {
      'email': _emailController.text.trim(),
      'senha': _senhaController.text,
    });
  }
}