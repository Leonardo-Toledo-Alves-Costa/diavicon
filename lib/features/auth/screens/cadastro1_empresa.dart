import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/core/widgets/custom_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro1Empresa extends StatelessWidget {
  final Map<String, dynamic> dadosCadastro; 
  const Cadastro1Empresa({super.key, required this.dadosCadastro});

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 10.0), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Bloco de Texto com Barra Laranja ────────────────
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  ),
                ),
                padding: const EdgeInsets.only(left: 16),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vamos conhecer melhor a\nsua Empresa!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1C1C),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Assim conseguimos personalizar\nsua experiência e oferecer\nsoluções adequadas ao seu tipo de\nprojeto.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4A4A4A),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: 5,
                        child: Image.asset(
                          'assets/images/cachorro.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      
                      Flexible(
                        flex: 4, 
                        // Transform.translate "flutua" o widget.
                        // offset: Offset(Eixo X, Eixo Y). 
                        // Valores negativos puxam para Esquerda e para Cima!
                        child: Transform.translate(
                          offset: const Offset(-30, -80), 
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/images/fala_dog2.png',
                                fit: BoxFit.contain,
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4.0), 
                                child: FittedBox( 
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Vamos\nComeçar?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1C1C1C),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Botões Inferiores ──────────────────────────────
              Row(
                children: [
                  CustomTextbutton(
                    text: '<   Voltar',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/empresa/gate', extra: dadosCadastro);
                      }
                    },
                  ),
                  
                  const SizedBox(width: 70), 
                  
                  CustomButton(
                    width: 120,
                    text: 'Começar',
                    onPressed: () {
                      context.push('/empresa/servicos', extra: dadosCadastro);
                    },
                  ),
                ],
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}


