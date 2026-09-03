import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators/validators_cadastro.dart';
import '../../../core/widgets/auth_layout.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../providers/auth_provider.dart';
import '../utils/auth_error_messages.dart';

class NovaSenhaScreen extends ConsumerStatefulWidget {
  const NovaSenhaScreen({super.key});

  @override
  ConsumerState<NovaSenhaScreen> createState() => _NovaSenhaScreenState();
}

class _NovaSenhaScreenState extends ConsumerState<NovaSenhaScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _senhaCtrl    = TextEditingController();
  final _confirmaCtrl = TextEditingController();

  bool _senhaVisible    = false;
  bool _confirmaVisible = false;

  @override
  void dispose() {
    _senhaCtrl.dispose();
    _confirmaCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizarSenha() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(recuperaSenhaControllerProvider.notifier)
          .atualizarSenha(_senhaCtrl.text);

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
          content: Text(authErrorMessage(e, fallback: 'Não foi possível atualizar a senha.')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(recuperaSenhaControllerProvider);

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
              const SizedBox(height: 36),
              const _InfoBlock(
                'Atualize a sua senha e continue a aproveitar da DIAVICON.',
              ),
              const SizedBox(height: 36),
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
                isLoading: isLoading,
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
