import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class RecuperaSenhaScreen extends StatefulWidget {
  const RecuperaSenhaScreen({super.key});

  @override
  State<RecuperaSenhaScreen> createState() => _RecuperaSenhaScreenState();
}

class _RecuperaSenhaScreenState extends State<RecuperaSenhaScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: 'diavicon://nova-senha',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link enviado! Verifique seu e-mail.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recupere sua senha',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1C1C),
                ),
              ),
              const SizedBox(height: 32),
              _InfoBlock(
                'Insira o seu endereço de email e receberá um link '
                'para atualização da sua senha na DIAVICON.',
              ),
              const SizedBox(height: 32),
              CustomTextField(
                label: 'Informe seu email',
                hint: 'joaosilva@email.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: ValidatorsCadastro.email,
              ),
              const Spacer(),
              CustomButton(
                text: 'Recuperar senha',
                onPressed: _enviarLink,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String text;
  const _InfoBlock(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF626365),
          height: 1.6,
        ),
      ),
    );
  }
}