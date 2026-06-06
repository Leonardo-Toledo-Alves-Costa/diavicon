import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class CadastroR0Screen extends StatefulWidget {
  const CadastroR0Screen({super.key});

  @override
  State<CadastroR0Screen> createState() => _CadastroR0ScreenState();
}

class _CadastroR0ScreenState extends State<CadastroR0Screen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _senhaCtrl    = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool _senhaVisible    = false;
  bool _confirmaVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  void _avancar() {
    if (!_formKey.currentState!.validate()) return;
    context.go('/register/dados', extra: {
      'email': _emailCtrl.text.trim(),
      'senha': _senhaCtrl.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seja Bem Vindo à',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1C),
                  height: 1.25,
                ),
              ),
              const Text(
                'DIAVICON!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Vamos iniciar o seu cadastro',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1C),
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                label: 'Seu melhor e-mail',
                hint: 'seuemail@email.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: ValidatorsCadastro.email,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Senha',
                hint: 'Sua senha',
                controller: _senhaCtrl,
                obscureText: !_senhaVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _senhaVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _senhaVisible = !_senhaVisible),
                ),
                validator: ValidatorsCadastro.senha,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Confirme a senha',
                hint: 'Sua senha',
                controller: _confirmaCtrl,
                obscureText: !_confirmaVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmaVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _confirmaVisible = !_confirmaVisible),
                ),
                validator: (v) =>
                    ValidatorsCadastro.confirmarSenha(v, _senhaCtrl.text),
              ),
              const Spacer(),
              CustomButton(
                text: 'Avançar',
                onPressed: _avancar,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}