import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class Cadastro2Cliente extends ConsumerStatefulWidget {
  // Recebe o "pacotão" de dados acumulado de todas as telas anteriores (R0, R1, R2)
  final Map<String, dynamic> dadosUsuario;

  const Cadastro2Cliente({super.key, required this.dadosUsuario});

  @override
  ConsumerState<Cadastro2Cliente> createState() => _Cadastro2ClienteState();
}

class _Cadastro2ClienteState extends ConsumerState<Cadastro2Cliente> {
  // NAVEGAR para o formulário de CNPJ/Endereço


  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            children: [
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
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
                            _buildCardHeader(),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Plano Enterprise',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Acompanhe de Perto seus Diversos Ativos!',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildFeatureItem(
                                      'Operação de Módulo de Gerenciamento e Monitoramento',
                                    ),
                                    _buildFeatureItem(
                                      'Módulo Finanças',
                                    ),
                                    _buildFeatureItem('Realização de Inspeção Visual preliminar'),
                                    _buildFeatureItem(
                                      'Armazenamento 100Gb',
                                    ),
                                    const Spacer(),
                                    _buildPriceSection(),
                                    const SizedBox(height: 14),
                                    _buildPrimaryButton(isLoading),
                                  ],
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
              const SizedBox(height: 16),
              _buildTrialButton(isLoading),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGETS AUXILIARES DE INTERFACE 

  Widget _buildCardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Center(
      child: Column(
        children: [
          RichText(
            text: const TextSpan(
              text: '249,90',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(
                  text: '/mês',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Estrutura sdcional + 5Gb R\$ 24,90',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => context.push('/register/cliente/welcome', extra: widget.dadosUsuario),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Selecionar plano',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildTrialButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isLoading ? null : () => context.push('/register/cliente/welcome', extra: widget.dadosUsuario),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'Experimente por 1 Mês Grátis',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
