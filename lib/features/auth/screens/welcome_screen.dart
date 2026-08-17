import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // O ESCUDO
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Image.asset(
                  'assets/images/escudo_diavicon.png',
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 20),

              // 2. LOGO DIAVICON
              Image.asset(
                'assets/images/logo_diavicon.png',
                height: 80,
                fit: BoxFit.contain,
              ),

              const SizedBox(),

              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Soluções para o diagnóstico da vida útil das construções',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark, 
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 3),

              CustomButton(
                text: 'Começar  →',
                onPressed: () => context.go('/login'),
              ),

              const SizedBox(height: 70),

              const Text(
                'Versão 1.0',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}