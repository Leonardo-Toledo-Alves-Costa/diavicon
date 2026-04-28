import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Cadastro3Empresa extends StatefulWidget {
  const Cadastro3Empresa({super.key});

  @override
  State<Cadastro3Empresa> createState() => _Cadastro3EmpresaState();
}

class _Cadastro3EmpresaState extends State<Cadastro3Empresa> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            children: [
              // Logo superior
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Card Principal
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Header: Melhor Oferta
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Melhor oferta',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            
                            // Conteúdo do Plano
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Plano Advanced',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Destrave o Potencial da Sua Empresa!',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.03,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Lista de Funcionalidades (com a barra lateral laranja)
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 7,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: const [
                                                _FeatureText(text: 'Acesso a 07 módulos de ensaio'),
                                                _FeatureText(text: 'Gerenciamento de Equipes'),
                                                _FeatureText(text: 'Relatórios Automáticos e Personalizáveis'),
                                                _FeatureText(text: 'Acompanhamento de RDO\'s e Gastos'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 10),
                                    
                                    // Preço
                                    Center(
                                      child: RichText(
                                        text: const TextSpan(
                                          text: '2499,90',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 40,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '/mês',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    const Center(
                                      child: Text(
                                        '+ R\$ 67,92 por usuário adicional da\n empresa(20% Off)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.greyDarkest,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 14),
                                    
                                    // Botão Selecionar
                                    SizedBox(
                                      width: double.infinity,
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: () => context.go('/projetos'),
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Selecionar plano',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
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

                    // Chevrons laterais (Conforme sua prototipagem)
                    Positioned(
                      left: -12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: () {}, // Lógica de carrossel futura
                          icon: const Icon(Icons.chevron_left_rounded),
                          iconSize: 32,
                          color: AppColors.greyMedium,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          onPressed: () {}, // Lógica de carrossel futura
                          icon: const Icon(Icons.chevron_right_rounded),
                          iconSize: 32,
                          color: AppColors.greyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botão rodapé: Trial
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => context.go('/projetos'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.primary, width: 1),
                    ),
                  ),
                  child: const Text(
                    'Experimente por 1 Mês Grátis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para os itens da lista
class _FeatureText extends StatelessWidget {
  final String text;
  const _FeatureText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}