import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';

class NovaSenhaScreen extends StatefulWidget {
  const NovaSenhaScreen({super.key});

  @override
  State<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends State<NovaSenhaScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _senhaCtrl   = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool _senhaVisible    = false;
  bool _confirmaVisible = false;
  bool _isLoading       = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizarSenha() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _senhaCtrl.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha atualizada com sucesso!'),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/login');
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
              const _InfoBlock(
                'Atualize a sua senha e continue a aproveitar da DIAVICON.',
              ),
              const SizedBox(height: 32),
              CustomTextField(
                label: 'Senha',
                hint: '••••••••••',
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
                label: 'Confirmar Senha',
                hint: '••••••••••',
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
                text: 'Recuperar senha',
                onPressed: _atualizarSenha,
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