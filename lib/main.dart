import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'routes/app_router.dart';
import 'features/auth/utils/cadastro_draft_store.dart';

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
  final draft = await CadastroDraftStore().load();
  container.read(rascunhoCadastroProvider.notifier).state = draft;
  final router = container.read(routerProvider);

  // Escuta apenas recuperação de senha; CurrentUserNotifier é o único dono da
  // sincronização de sessão para evitar respostas fora de ordem duplicadas.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      router.go('/nova-senha');
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DiaviconApp(),
    ),
  );
}
