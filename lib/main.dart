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

  // Configuração do Supabase.
  //
  // O arquivo principal é `assets/config.env`, sem ponto no começo do nome:
  // muitos servidores de hospedagem recusam qualquer arquivo iniciado por
  // ponto, e com isso o app ficava parado para sempre na tela de abertura.
  // O `.env` da raiz não vai mais no app (seria baixável por qualquer um);
  // para rodar local, use --dart-define ou o próprio assets/config.env.
  await _carregarConfiguracao();
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseChave = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isEmpty || supabaseChave.isEmpty) {
    runApp(const _TelaConfiguracaoFaltando());
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseChave);

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


/// Lê a configuração, tentando os nomes possíveis do arquivo.
Future<void> _carregarConfiguracao() async {
  for (final arquivo in const ['assets/config.env']) {
    try {
      await dotenv.load(fileName: arquivo);
      if ((dotenv.env['SUPABASE_URL'] ?? '').isNotEmpty) return;
    } catch (_) {
      // Arquivo ausente ou recusado pelo servidor: tenta o próximo.
    }
  }
  // Último recurso: valores passados na compilação (--dart-define).
  const url = String.fromEnvironment('SUPABASE_URL');
  const chave = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && chave.isNotEmpty) {
    dotenv.env['SUPABASE_URL'] = url;
    dotenv.env['SUPABASE_ANON_KEY'] = chave;
  }
}

/// Em vez de ficar presa na tela de abertura, a tela diz o que faltou.
class _TelaConfiguracaoFaltando extends StatelessWidget {
  const _TelaConfiguracaoFaltando();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.settings_ethernet_rounded, size: 44, color: Color(0xFFA85A00)),
                SizedBox(height: 16),
                Text(
                  'Configuração não encontrada',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 10),
                Text(
                  'O app não conseguiu ler o arquivo de configuração '
                  '(assets/config.env). Confira se a pasta assets foi enviada '
                  'por inteiro e se o servidor não está bloqueando esse arquivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
