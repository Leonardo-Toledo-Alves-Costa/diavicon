import 'dart:async';

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

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final container = ProviderContainer();
  container.read(routerProvider);

  runApp(
    UncontrolledProviderScope(container: container, child: const DiaviconApp()),
  );

  unawaited(_finishAuthBootstrap(container));
}

Future<void> _finishAuthBootstrap(ProviderContainer container) async {
  try {
    await container.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
  } finally {
    container.read(authBootstrapCompleteProvider.notifier).state = true;
  }
}
