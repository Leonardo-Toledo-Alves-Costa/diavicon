import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/features/app_shell/widgets/perfil_header.dart';
import 'package:flutter/material.dart';

class PerfilCentralAjuda extends StatelessWidget {
  const PerfilCentralAjuda({super.key});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Column(
        children: [
          PerfilHeader(topPadding: topPadding, paginaAtual: 'Ajuda'),
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
                          'Central de ajuda',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E3E3D),
                            fontFamily: 'Lato',
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      const _HelpItem(title: 'Versão'),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Política de privacidade', onTap: () {}),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Licenças de terceiros', onTap: () {}),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Termos de uso', onTap: () {}),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Regras da plataforma', onTap: () {}),
                      const SizedBox(height: 25),
                      _HelpItem(title: 'Suporte', onTap: () {}),
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

class _HelpItem extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _HelpItem({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAction = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF3E3E3D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasAction)
              const Icon(
                Icons.open_in_new_outlined,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
