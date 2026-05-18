import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro2Empresa extends StatefulWidget {
  const Cadastro2Empresa({super.key});

  @override
  State<Cadastro2Empresa> createState() => _Cadastro2EmpresaState();
}

class _Cadastro2EmpresaState extends State<Cadastro2Empresa> {
  late final List<bool> _selecionados =
      List<bool>.filled(6, false);

  final List<String> servicos = [
    'Controle tecnológico',
    'Ensaios laboratoriais',
    'Geotecnia',
    'Pavimentação',
    'Concreto',
    'Consultoria',
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  MediaQuery.of(context).padding.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        Image.asset(
                          'assets/images/logo_diavicon.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 10),

                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: 0.68,
                            minHeight: 9,
                            backgroundColor:
                                Colors.grey.shade400,
                            valueColor:
                                const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Quais serviços que você realiza?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: servicos.length,
                              padding:
                                  const EdgeInsets.all(10),
                              separatorBuilder:
                                  (_, __) =>
                                      const Divider(height: 1),
                              itemBuilder: (context, index) {
                                return CheckboxListTile(
                                  value:
                                      _selecionados[index],
                                  onChanged: (value) {
                                    setState(() {
                                      _selecionados[index] =
                                          value ?? false;
                                    });
                                  },
                                  activeColor:
                                      AppColors.primary,
                                  title: Text(
                                    servicos[index],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity
                                          .leading,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                MediaQuery.of(context)
                                    .padding
                                    .bottom,
                          ),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/login');
                                  }
                                },
                                style:
                                    TextButton.styleFrom(
                                  foregroundColor:
                                      AppColors.primary,
                                ),
                                child: const Text(
                                  '<   Voltar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),

                              const Spacer(),

                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style:
                                      ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.primary,
                                    foregroundColor:
                                        Colors.white,
                                    elevation: 0,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Avançar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w600,
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}