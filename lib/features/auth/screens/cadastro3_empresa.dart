import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class Cadastro3Empresa extends StatefulWidget {
  const Cadastro3Empresa({super.key});

  @override
  State<Cadastro3Empresa> createState() =>
      _Cadastro3EmpresaState();
}

class _Cadastro3EmpresaState
    extends State<Cadastro3Empresa> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                14,
                18,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/logo_diavicon.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration:
                                    const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                      BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Melhor oferta',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ),

                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      const Text(
                                        'Plano Advanced',
                                        style: TextStyle(
                                          color:
                                              AppColors.primary,
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),

                                      const SizedBox(
                                          height: 16),

                                      const Text(
                                        'Destrave o Potencial da Sua Empresa!',
                                        style: TextStyle(
                                          color:
                                              AppColors.textDark,
                                          fontSize: 24,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),

                                      const SizedBox(
                                          height: 24),

                                      const _BeneficioItem(
                                        texto:
                                            'Acesso a 07 módulos de ensaio',
                                      ),

                                      const _BeneficioItem(
                                        texto:
                                            'Gerenciamento de Equipes',
                                      ),

                                      const _BeneficioItem(
                                        texto:
                                            'Relatórios Automáticos e Personalizáveis',
                                      ),

                                      const _BeneficioItem(
                                        texto:
                                            'Acompanhamento de RDOs e Gastos',
                                      ),

                                      const Spacer(),

                                      Center(
                                        child: RichText(
                                          text: const TextSpan(
                                            text: '2499,90',
                                            style:
                                                TextStyle(
                                              color:
                                                  AppColors
                                                      .primary,
                                              fontSize: 42,
                                              fontWeight:
                                                  FontWeight
                                                      .w900,
                                            ),
                                            children: [
                                              TextSpan(
                                                text:
                                                    '/mês',
                                                style:
                                                    TextStyle(
                                                  color: Colors
                                                      .black,
                                                  fontSize:
                                                      18,
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(
                                          height: 10),

                                      const Center(
                                        child: Text(
                                          '+ R\$ 67,92 por usuário adicional da empresa\n(20% OFF)',
                                          textAlign:
                                              TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors
                                                .greyDarkest,
                                            fontSize: 14,
                                            fontWeight:
                                                FontWeight
                                                    .w500,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(
                                          height: 20),

                                      SizedBox(
                                        width:
                                            double.infinity,
                                        height: 52,
                                        child:
                                            ElevatedButton(
                                          onPressed: () {},
                                          style:
                                              ElevatedButton
                                                  .styleFrom(
                                            backgroundColor:
                                                AppColors
                                                    .primary,
                                            foregroundColor:
                                                Colors.white,
                                            elevation: 0,
                                            shape:
                                                RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                10,
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            'Selecionar plano',
                                            style:
                                                TextStyle(
                                              fontSize: 18,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
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

                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {},
                          style:
                              ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor:
                                Colors.transparent,
                            foregroundColor:
                                AppColors.primary,
                            shadowColor:
                                Colors.transparent,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Experimente por 1 Mês',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.w700,
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
      ),
    );
  }
}

class _BeneficioItem extends StatelessWidget {
  final String texto;

  const _BeneficioItem({
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(
              top: 6,
            ),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}