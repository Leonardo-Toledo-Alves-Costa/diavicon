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
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authControllerProvider.notifier).login(
        _emailController.text.trim(), 
        _senhaController.text
      );
      if (mounted) context.go('/projetos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao entrar. Verifique suas credenciais.'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return AuthLayout(
      logoHeight: 200, // Ajustado para dar mais respiro ao formulário
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            // O segredo para evitar o overflow
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 35, 28, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Bem vindo!',
                      style: TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.w900, 
                        color: AppColors.textDark, // #626365 [cite: 85]
                        fontFamily: 'Lato', // [cite: 80]
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    CustomTextField(
                      label: 'Login',
                      hint: 'Seu email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    CustomTextField(
                      label: 'Senha',
                      hint: 'Sua senha',
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _ocultarSenha ? Icons.visibility_off : Icons.visibility, 
                          size: 20,
                          color: AppColors.hintText,
                        ),
                        onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                      ),
                      validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _lembrarMe,
                                activeColor: AppColors.primary, // #D99100 [cite: 91]
                                onChanged: (val) => setState(() => _lembrarMe = val!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Lembrar-me',
                              style: TextStyle(color: AppColors.textDark, fontSize: 14, fontFamily: 'Lato'),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () { /* TODO: Resgatar senha */ },
                          child: const Text(
                            'Resgatar Senha', 
                            style: TextStyle(
                              color: AppColors.primary, 
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Lato',
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),

                    CustomButton(
                      text: 'Entrar  →',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _fazerLogin,
                    ),

                    // Espaçamento flexível para subir os ícones sociais
                    const SizedBox(height: 40), 

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/ic_linkedin.png', height: 40),
                        const SizedBox(width: 30),
                        Image.asset('assets/images/ic_google.png', height: 40),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    Column(
                      children: [
                        const Text(
                          'AINDA NÃO POSSUI UMA CONTA?', 
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.grey, 
                            letterSpacing: 0.8,
                            fontFamily: 'Lato',
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/register'),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'CADASTRE-SE', 
                              style: TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.w900, 
                                fontSize: 15,
                                fontFamily: 'Lato',
                              ),
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
        },
      ),
    );
  }
}