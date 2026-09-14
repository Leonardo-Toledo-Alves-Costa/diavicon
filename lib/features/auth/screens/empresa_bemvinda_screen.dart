import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:diavicon/routes/app_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/auth_layout.dart';

// 🔥 Importe os provedores para ter acesso à memória e ao usuário real
import '../../auth/providers/auth_provider.dart';

class EmpresaBemVindaScreen extends ConsumerWidget {
  final Map<String, dynamic> dadosUsuario;

  const EmpresaBemVindaScreen({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 1. BLINDAGEM DE DADOS: Puxa da memória caso a rota perca o parâmetro 'extra'
    final rascunho = ref.watch(rascunhoCadastroProvider);
    final usuarioLogado = ref.watch(currentUserProvider);

    // Cruzamento inteligente: tenta pegar do Usuário Banco -> Rota -> Rascunho Memória
    final nome =
        usuarioLogado?.nome ??
        dadosUsuario['nome'] ??
        rascunho['nome'] ??
        'Gestor';
    final sobrenome =
        usuarioLogado?.sobrenome ??
        dadosUsuario['sobrenome'] ??
        rascunho['sobrenome'] ??
        '';

    final empresaMap =
        dadosUsuario['empresa'] as Map? ?? rascunho['empresa'] as Map?;
    final cargo = empresaMap?['cargo'] as String? ?? 'Administrador';
    final nivel = empresaMap?['nivel'] as String? ?? '';

    final String? fotoUsuario =
        usuarioLogado?.fotoUrl ??
        dadosUsuario['foto_url'] ??
        dadosUsuario['fotoPath'] ??
        empresaMap?['fotoPath'];

    final String nomeExibicao = nome.toString().isNotEmpty
        ? nome.toString()
        : 'Gestor';

    // AJUSTE O BALÃO AQUI:
    const double bubbleOffsetX = -15.0;
    const double bubbleOffsetY = -80.0;

    return AuthLayout(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem vindo $nomeExibicao!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Comece a ter o controle de suas\nestruturas na palma da sua mão!',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.greyVeryLight,
                  backgroundImage: _getImagemPerfil(fotoUsuario),
                  child: fotoUsuario == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.greyLight,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$nome $sobrenome',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cargo,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (nivel.isNotEmpty)
                        Text(
                          nivel,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 70),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Image.asset(
                    'assets/images/cachorro.png',
                    fit: BoxFit.contain,
                    height: 160,
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Transform.translate(
                    offset: const Offset(bubbleOffsetX, bubbleOffsetY),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
                            height: 1.4,
                            fontFamily: 'Lato',
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Hora de começar a\nacompanhar suas\nestruturas! Serei o\nseu ',
                            ),
                            TextSpan(
                              text: 'guia!',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),

            Center(
              child: CustomButton(
                text: 'Começar',
                width: 160,
                height: 48,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                onPressed: () {
                  // Encerra a transição protegida do onboarding e limpa o rascunho.
                  ref.read(bloqueioDeRotaProvider.notifier).state = false;
                  ref.invalidate(rascunhoCadastroProvider);
                  context.goNamed(AppRouteNames.projects);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getImagemPerfil(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }
}
