import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _ocultarSenha = true;
  bool _lembrarMe = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return AuthLayout(
      logoHeight: 220, // Forçando o logo a crescer 0.5x mais
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 35, 28, 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bem vindo!',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textDark),
              ),
              const SizedBox(height: 25),
              
              CustomTextField(
                label: 'Login',
                hint: 'Seu email',
                controller: _emailController,
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              
              CustomTextField(
                label: 'Senha',
                hint: 'Sua senha',
                controller: _senhaController,
                obscureText: _ocultarSenha,
                suffixIcon: IconButton(
                  icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                ),
                validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Checkbox(
                    value: _lembrarMe,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _lembrarMe = val!),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Resgatar Senha', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),

              CustomButton(
                text: 'Entrar  →',
                isLoading: isLoading,
                onPressed: isLoading ? null : () => _fazerLogin(),
              ),

              // EM VEZ DE SPACER, USAMOS UM GAP FIXO PARA SUBIR OS BOTÕES
              const SizedBox(height: 50), 

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/ic_linkedin.png', height: 45),
                  const SizedBox(width: 35),
                  Image.asset('assets/images/ic_google.png', height: 45),
                ],
              ),
              
              const SizedBox(height: 20),

              Column(
                children: [
                  const Text('AINDA NÃO POSSUI UMA CONTA?', 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('CADASTRE-SE', 
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
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

  // O resto da função _fazerLogin continua igual...
  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authControllerProvider.notifier).login(_emailController.text.trim(), _senhaController.text);
      if (mounted) context.go('/projetos');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao entrar.')));
    }
  }
}