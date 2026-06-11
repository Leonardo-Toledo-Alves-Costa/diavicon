import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'routes/app_router.dart'; // Importe o arquivo de rotas

// 1. Mude para ConsumerWidget
class DiaviconApp extends ConsumerWidget {
  const DiaviconApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. Leia o router que acabamos de criar
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Diavicon',
      debugShowCheckedModeBanner: false,
      
      // 3. Passe o router lido para o MaterialApp
      routerConfig: router, 
      
      theme: ThemeData(
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme,
        ),
        useMaterial3: true,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
      ),
    );
  }
}