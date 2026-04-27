import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';

/// Tela final de boas-vindas após cadastro completo da empresa.
/// Rota: /empresa/bemvinda
class EmpresaBemVindaScreen extends ConsumerWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaBemVindaScreen({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nome = dadosUsuario['nome'] as String? ?? '';
    final sobrenome = dadosUsuario['sobrenome'] as String? ?? '';
    final cargo = (dadosUsuario['empresa'] as Map?)?['cargo'] as String? ??
        dadosUsuario['cargo'] as String? ?? '';
    final nivel = (dadosUsuario['empresa'] as Map?)?['nivel'] as String? ?? '';
    final nomeEmpresa =
        (dadosUsuario['empresa'] as Map?)?['nome'] as String? ?? 'Sua Empresa';

    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card de boas-vindas com nome da empresa
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.greyVeryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Logo placeholder da empresa
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.inputBorder, width: 2),
                    ),
                    child: const Icon(
                      Icons.domain,
                      size: 40,
                      color: AppColors.greyLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BEM VINDA!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.greyMediumDark,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nomeEmpresa.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card do usuário responsável
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greyVeryLight),
              ),
              child: Row(
                children: [
                  // Avatar do usuário
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.greyVeryLight,
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: AppColors.greyLight,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$nome $sobrenome',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cargo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.greyMedium,
                        ),
                      ),
                      if (nivel.isNotEmpty)
                        Text(
                          nivel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.greyMedium,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mascote com balão
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/escudo_diavicon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.pets,
                      size: 100,
                      color: AppColors.greyLight,
                    ),
                  ),
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.greyVeryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hora de começar a\nacompanhar suas\nestruturas! Serei o\nseu guia!',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textDark,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            CustomButton(
              text: '✓  Começar',
              onPressed: () => context.go('/projetos'),
            ),
          ],
        ),
      ),
    );
  }
}