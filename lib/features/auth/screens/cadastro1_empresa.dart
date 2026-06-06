import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/custom_text_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro1Empresa extends StatelessWidget {
  final Map<String, dynamic> dadosUsuario; // Adicione isso
  const Cadastro1Empresa({super.key, required this.dadosUsuario});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AuthLayout(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: AppColors.primary,
                              width: 5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          14,
                          12,
                        ),
                        child: const Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vamos conhecer melhor a\nsua Empresa!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Assim conseguimos personalizar\nsua experiência e oferecer\nsoluções adequadas ao seu tipo de\nprojeto.',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      SizedBox(
                        height: screenHeight * 0.30,
                        child: Image.asset(
                          'assets/images/escudo_diavicon.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const Spacer(),

                      Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              MediaQuery.of(context).padding.bottom,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            CustomTextbutton(
                              text: '<   Voltar',
                              onPressed: () {},
                            ),
                            const SizedBox(width: 40),
                            CompactButton(
                              text: 'Começar',
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}