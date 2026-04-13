import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'routes/app_router.dart';

class DiaviconApp extends StatelessWidget {
  const DiaviconApp({super.key});

  @override
  Widget build(BuildContext context) {
    // .router para o Flutter saber que o GoRouter controla as telas
    return MaterialApp.router(
      title: 'Diavicon',
      debugShowCheckedModeBanner: false,
      
      // Configuração das rotas
      routerConfig: AppRouter.router,
      
      // Configuração de Tema Global da Diavicon
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        
        // Padronização global dos textos
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(color: AppColors.textDark),
        ),
      ),
    );
  }
}