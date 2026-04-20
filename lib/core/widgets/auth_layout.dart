import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final Widget child;
  final double logoHeight;

  const AuthLayout({
    super.key, 
    required this.child, 
    this.logoHeight = 180, // Aumentado para o novo padrão
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: Column(
        children: [
          // Área Superior: 20% da tela para um cabeçalho mais imponente
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
          // Área Inferior: 80% da tela para o formulário
          Expanded(
            flex: 80, 
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}