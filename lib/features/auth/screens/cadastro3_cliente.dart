import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/auth_layout.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Cadastro3Cliente extends ConsumerStatefulWidget {
  // Recebe o "pacotão" de dados acumulado de todas as telas anteriores (R0, R1, R2)
  final Map<String, dynamic> dadosUsuario;

  const Cadastro3Cliente({super.key, required this.dadosUsuario});

  @override
  ConsumerState<Cadastro3Cliente> createState() => _Cadastro3ClienteState();
}

class _Cadastro3ClienteState extends ConsumerState<Cadastro3Cliente> {
  

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);


    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  child: Column(
                    children: [
                      const SizedBox(height: 2),
                      Center(
                        child: Image.asset(
                          'assets/images/logo_diavicon.png',
                          width: 180,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: constraints.maxHeight * 0.73,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.primary,
                                    width: 4,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.only(left: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bem vindo Fulano!',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      height: 1.08,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Comece a ter o controle de suas\nestruturas na palma da sua mão!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textDark,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/images/user.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fulano Ciclano',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                            height: 1.05,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Engenheiro Civil',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Diretor (CEO)',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            SizedBox(
                              height: 275,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: Image.asset(
                                      'assets/images/cachorro.png',
                                      width: 250,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 0,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 152,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.greyVeryLight,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: RichText(
                                        textAlign: TextAlign.center,
                                        text: const TextSpan(
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textDark,
                                            height: 1.25,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          children: [
                                            TextSpan(
                                              text:
                                                  'Hora de começar a\nacompanhar suas\nestruturas! Serei o\nseu ',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textDark,
                                                height: 1.25,
                                              ),
                                            ),
                                            TextSpan(
                                              text: 'guia!',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: 108,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () => (),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Começar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          );
        },
      ),
    ));
  }
}

