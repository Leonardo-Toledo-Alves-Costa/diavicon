import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 1. Importe o Riverpod aqui
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializações de Infra
  await dotenv.load(fileName: ".env");
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  print('--- DEBUG SUPABASE URL: "$supabaseUrl" ---');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 2. Abrace o seu app com o ProviderScope
  runApp(
    const ProviderScope(
      child: DiaviconApp(),
    ),
  );
}