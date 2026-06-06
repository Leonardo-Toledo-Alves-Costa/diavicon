import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';

/// Tela final de boas-vindas após o cadastro completo da empresa no Supabase
class EmpresaBemVindaScreen extends ConsumerWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaBemVindaScreen({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Extração dos dados para exibição nos cards
    final nome = dadosUsuario['nome'] as String? ?? '';
    final sobrenome = dadosUsuario['sobrenome'] as String? ?? '';
    
    // Pegando dados de dentro do mapa 'empresa' que criamos na tela anterior
    final empresaMap = dadosUsuario['empresa'] as Map?;
    final cargo = empresaMap?['cargo'] as String? ?? 'Gestor';
    final nivel = empresaMap?['nivel'] as String? ?? '';
    final nomeEmpresa = empresaMap?['nome'] as String? ?? 'Sua Empresa';

    return AuthLayout(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CABEÇALHO DA EMPRESA 
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.greyVeryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Logo Placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.inputBorder, width: 2),
                    ),
                    child: const Icon(
                      Icons.domain,
                      size: 40,
                      color: AppColors.greyLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BEM-VINDA!',
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
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // PERFIL DO USUÁRIO RESPONSÁVEL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greyVeryLight),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.greyVeryLight,
                    child: const Icon(Icons.person, size: 30, color: AppColors.greyLight),
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
                        style: const TextStyle(fontSize: 13, color: AppColors.greyMedium),
                      ),
                      if (nivel.isNotEmpty)
                        Text(
                          nivel,
                          style: const TextStyle(fontSize: 13, color: AppColors.greyMedium),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            //MASCOTE/GUIA 
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Substitua pelo seu asset real ou mantenha o ícone de fallback
                  Image.asset(
                    'assets/images/escudo_diavicon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_rounded, 
                      size: 100, 
                      color: AppColors.greyLight
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.greyVeryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Hora de começar a\nacompanhar suas\nestruturas! Serei o\nseu guia!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BOTÃO DE ENTRADA NO APP 
            CustomButton(
              text: '✓  Começar',
              onPressed: () {
                // GoRouter mata toda a pilha de cadastro e abre a Home
                context.go('/projetos');
              },
            ),
          ],
        ),
      ),
    );
  }
}