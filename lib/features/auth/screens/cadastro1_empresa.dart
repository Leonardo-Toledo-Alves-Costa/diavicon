import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro1Empresa extends StatelessWidget {
  final Map<String, dynamic> dadosUsuario; // Adicione isso
  const Cadastro1Empresa({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context) {
    final screenwidth = MediaQuery.of(context).size.width;
    final screenheight = MediaQuery.of(context).size.height;
    return AuthLayout(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: AppColors.primary, width: 5),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Vamos conhecer melhor a\nsua Empresa!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.05,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Assim conseguimos personalizar\nsua experiência e oferecer\nsoluções adequadas ao seu tipo de\nprojeto.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                height: screenheight * 0.30,
                color: AppColors.background,
                child: Image.asset(
                  'assets/images/escudo_diavicon.png',
                  fit: BoxFit.contain,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomTextbutton(text: '<   Voltar', onPressed: () {}),
                  SizedBox(width: screenwidth * 0.2),
                  CompactButton(
                    text: 'Começar',
                    onPressed: () => context.push(
                      '/empresa/servicos', extra: dadosUsuario,
                    ), // Leva para os Checkboxes (Cadastro2)
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
