import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  print('--- DEBUG SUPABASE URL: "$supabaseUrl" ---');
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final container = ProviderContainer();
  final router = container.read(routerProvider);

  // Escuta alterações de Auth globais do sistema (como recuperação de senha)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      router.go('/nova-senha');
    } else if (data.event == AuthChangeEvent.signedIn) {
      // 🔥 Sincroniza o perfil reativo no Riverpod imediatamente após o login bem-sucedido
      container.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DiaviconApp(),
    ),
  );
}