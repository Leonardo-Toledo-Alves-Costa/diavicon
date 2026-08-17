import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro0Empresa extends StatelessWidget {
  final Map<String, dynamic> dadosCadastro;

  const Cadastro0Empresa({super.key, required this.dadosCadastro});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AuthLayout(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 1),

              // ── Título (Quebra exata e blindado contra telas menores) ────────────────
              Container(
                width: double.infinity,
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    textAlign: TextAlign.left,
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 26, // O FittedBox vai reduzir isso automaticamente se precisar
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF1C1C1C),
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(text: 'Sua empresa já é cadastrada\n'),
                        TextSpan(text: 'da '),
                        TextSpan(
                          text: 'DIAVICON',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(text: '?'),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Botão Principal ────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    context.go('/empresa/onboarding', extra: dadosCadastro);
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Quero cadastrar minha empresa',
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Card de Aviso (Com FittedBox no título) ──────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'Sou membro de uma empresa',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C1C1C),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Entre em contato com o administrador da sua empresa e peça para ele enviar um convite de acesso para o seu e-mail. Assim, o seu vínculo será automático!',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF1C1C1C),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Botão Voltar ───────────────────────────────
              CustomTextbutton(
                text: '<   Voltar',
                onPressed: () {
                  // Se o celular conseguir fazer o pop nativo, ele faz. 
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    // Se não, você força a volta para a rota exata (ajuste o '/rota' para o caminho real da sua tela anterior)
                    context.go('/register/perfil', extra: dadosCadastro);
                  }
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}