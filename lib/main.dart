import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // init supá
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  try {
    // Tenta buscar apenas 1 linha da tabela empresas
    final testQuery = await Supabase.instance.client
        .from('empresas')
        .select()
        .limit(1);
    
    print('✅ CONEXÃO ESTABELECIDA: O banco respondeu com $testQuery');
  } catch (e) {
    print('❌ ERRO DE CONEXÃO: Algo deu errado na comunicação -> $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diavicon',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const Scaffold(
        body: Center(child: Text('Conexão com Supabase Ativa!')),
      ),
    );
  }
}