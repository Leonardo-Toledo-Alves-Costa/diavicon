import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/home/screens/perfil_header.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PerfilNotificacoes extends StatelessWidget {
  const PerfilNotificacoes({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Notificações'),
          const SizedBox(height: 35),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -18),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: Text(
                          'Notificações',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E3E3D),
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Notificações push estão desativadas',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1C),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF3E3E3D),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Novidades da DIAVICON',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E3E3D),
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fique por dentro das últimas novidades da\nDIAVICON e conte-nos como podemos\nmelhorar.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Color(0xFF3E3E3D),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _NotificationRow(title: 'Notícias e programas'),
                      _NotificationRow(title: 'Feedback'),
                      _NotificationRow(title: 'Regulamentos'),
                      const Divider(height: 28, thickness: 1),
                      const Text(
                        'Cancelar inscrição de ofertas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E3E3D),
                          fontFamily: 'Lato',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Você continuará recebendo notificações sobre\na atividade da sua conta.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Color(0xFF3E3E3D),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _NotificationRow(title: 'Todas as ofertas e novidades'),
                      const SizedBox(height: 18),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Ao aceitar mensagens de texto, você concorda\nem receber mensagens de marketing\nautomatizadas da DIAVICON em +55 31\n99999 1234. Para receber mensagens em\noutro número, ',
                            ),
                            TextSpan(
                              text:
                                  'atualize as configurações de\nnúmero de telefone',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // open the phone settings / profile page here
                                },
                            ),
                            const TextSpan(
                              text: ' na sua página de\ninformações pessoais.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Voltar',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Salvar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final String title;

  const _NotificationRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3E3E3D),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ativado: Email',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9A9A9A)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Editar',
              style: TextStyle(
                color: Color(0xFF3E3E3D),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
