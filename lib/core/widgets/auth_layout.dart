import 'package:flutter/material.dart';

/// Layout base das telas de autenticação e cadastro.
/// Estrutura: logo no topo (20%) + card branco arredondado (80%).
/// SafeArea aplicado no topo e no fundo para evitar que botões
/// fiquem atrás da barra de navegação do sistema.
class AuthLayout extends StatelessWidget {
  final Widget child;
  final double logoHeight;

  const AuthLayout({
    super.key,
    required this.child,
    this.logoHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: Column(
        children: [
          // ── Área superior: logo ──────────────────────────────────────────
          Expanded(
            flex: 20,
            child: SafeArea(
              bottom: false,
              child: Container(
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/logo_diavicon.png',
                  height: logoHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.domain, size: 70, color: Colors.grey),
                ),
              ),
            ),
          ),

          // ── Área inferior: conteúdo ──────────────────────────────────────
          Expanded(
            flex: 80,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              // Padding extra no fundo para não esconder botões
              // atrás da barra de navegação do sistema (gesture bar / nav bar)
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}