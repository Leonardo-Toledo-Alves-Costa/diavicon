import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';

/// Tela de onboarding da empresa com mascote.
/// Rota: /empresa/onboarding
class EmpresaOnboardingScreen extends ConsumerWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaOnboardingScreen({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = dadosUsuario['tipo'] as String? ?? '';
    final isCliente = tipo == 'Cliente';

    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCliente
                        ? 'Vamos conhecer melhor os seus ativos!'
                        : 'Vamos conhecer melhor a sua Empresa!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Assim conseguimos personalizar sua experiência e oferecer soluções adequadas ao seu tipo de projeto.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/escudo_diavicon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.pets,
                      size: 140,
                      color: AppColors.greyLight,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.greyVeryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Vamos\nComeçar?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      context.go('/empresa/gate', extra: dadosUsuario),
                  child: const Text(
                    '< Voltar',
                    style: TextStyle(color: AppColors.greyMedium),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 160,
                  child: CustomButton(
                    text: 'Começar',
                    onPressed: () => context.go(
                      '/empresa/servicos',
                      extra: dadosUsuario,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}