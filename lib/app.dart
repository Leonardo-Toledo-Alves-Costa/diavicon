import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/providers/auth_provider.dart';
import 'routes/app_router.dart'; // Importe o arquivo de rotas

// 1. Mude para ConsumerWidget
class DiaviconApp extends ConsumerWidget {
  const DiaviconApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapComplete = ref.watch(authBootstrapCompleteProvider);
    final theme = ThemeData(
      textTheme: GoogleFonts.latoTextTheme(Theme.of(context).textTheme),
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
    );

    if (!bootstrapComplete) {
      return MaterialApp(
        title: 'Diavicon',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Diavicon',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: theme,
    );
  }
}
