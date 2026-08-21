import 'package:diavicon/features/auth/screens/cadastro0_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro1_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro2_cliente.dart';
import 'package:diavicon/features/auth/screens/cadastro3_cliente.dart';
import 'package:diavicon/features/auth/screens/completar_cadastro_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_bemvinda_screen.dart';
import 'package:diavicon/features/auth/screens/empresa_cadastro_screen.dart';
import 'package:diavicon/features/elementos/screens/elementos_home_screen.dart';
import 'package:diavicon/features/elementos/screens/info_elementos_screen.dart';
import 'package:diavicon/features/elementos/screens/relatorios_screen.dart';
import 'package:diavicon/features/empresa/screens/empresa_screen.dart';
import 'package:diavicon/features/home/screens/perfil_Minha_Conta.dart';
import 'package:diavicon/features/home/screens/perfil_Screen.dart';
import 'package:diavicon/features/home/screens/perfil_central_ajuda.dart';
import 'package:diavicon/features/home/screens/perfil_minha_privacidade.dart';
import 'package:diavicon/features/home/screens/perfil_notificacoes.dart';
import 'package:diavicon/features/projetos/screens/notificacoes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diavicon/features/estrutura/screens/estruturas_tab_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';
import '../../features/auth/screens/recupera_senha_screen.dart';
import '../../features/auth/screens/nova_senha_screen.dart';

import '../../features/auth/screens/cadastro0_empresa.dart';
import '../../features/auth/screens/cadastro1_empresa.dart';
import '../../features/auth/screens/cadastro2_empresa.dart';
import '../../features/auth/screens/cadastro3_empresa.dart';

// ── Elementos Estruturais ─────────────────────────────────────────────────────

import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart';


// ── feed empresas produtos ─────────────────────────────────────────────────────
import '../../features/empresas_servicos/screens/empresas_screen.dart';

Map<String, dynamic> _routeExtra(Object? extra) {
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) {
    return extra.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String? _stringExtra(Map<String, dynamic> extra, String key) {
  final value = extra[key];
  if (value == null) return null;
  return value.toString();
}

String? _elementoTipo(Map<String, dynamic> extra) {
  final tipo = _stringExtra(extra, 'tipo');
  if (tipo == null || tipo.trim().isEmpty) return null;
  return tipo.split('-').first.trim();
}

String? _elementoTipologia(Map<String, dynamic> extra) {
  final tipo = _stringExtra(extra, 'tipo');
  if (tipo == null || !tipo.contains('-')) return null;
  return tipo.split('-').skip(1).join('-').trim();
}

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  final routerAlarme = ValueNotifier<bool>(false);

  // Se o Riverpod mudar, recarrega as rotas
  ref.listen(currentUserProvider, (previous, next) {
    routerAlarme.value = !routerAlarme.value;
  });

  // Se o Supabase logar/deslogar, recarrega as rotas
  Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    routerAlarme.value = !routerAlarme.value;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: routerAlarme,

    redirect: (context, state) {
      // O ROTEADOR VÊ SE O ESCUDO ESTÁ ATIVADO
      // Se estiver, ele aborta qualquer redirecionamento e deixa a tela atual em paz!
      final bloqueioAtivo = ref.read(bloqueioDeRotaProvider);
      if (bloqueioAtivo) {
        print('[ROUTER] Escudo ativado! Ignorando redirecionamentos.');
        return null;
      }

      final path = state.uri.path;
      final usuario = ref.read(currentUserProvider);

      final bool isLoggedIn = usuario != null;
      final bool isAtivo = usuario?.ativo ?? false;

      print('====== [RASTREADOR DIRETRIZ] ======');
      print('• Tentando ir para: $path');
      print('• Estado -> Logado: $isLoggedIn | Ativo: $isAtivo');

      // --- Redirecionamento para usuários NÃO logados ---
      if (!isLoggedIn) {
        final bool isPublic =
            path == '/' ||
            path == '/login' ||
            path.startsWith('/register') ||
            path.startsWith('/empresa/') ||
            path == '/completar-cadastro' ||
            path == '/recuperar-senha' ||
            path == '/nova-senha';

        if (!isPublic) {
          print('❌ [BLOQUEIO] Rota privada sem login. Forçando: /login');
          return '/login';
        }
        return null;
      }

      // --- Redirecionamento para usuários LOGADOS ---
      if (isLoggedIn) {
        // REGRA DO CONVIDADO (COM EXCEÇÃO DA TELA BEM-VINDA):
        // Se já tem empresa, não pode acessar os formulários de cadastro.
        // MAS a tela '/empresa/bemvinda' está liberada para o fluxo de finalização
        // REGRA DO CONVIDADO (COM EXCEÇÃO DA TELA BEM-VINDA E CADASTRO):
        // Adiciono '/empresa/cadastro' nas exceções. Assim o roteador não
        // se desespera e não te chuta pra projetos no exato milissegundo em que o banco salva os dados!
        final bool jaTemEmpresa = usuario.empresaId != null;
        if (jaTemEmpresa &&
            path.startsWith('/empresa/') &&
            path != '/empresa/bemvinda' &&
            path != '/empresa/cadastro') {
          print('➡️ [DESVIO] Usuário já tem empresa. Indo para /projetos');
          return '/projetos';
        }

        // Se estiver no ecossistema da empresa (e não foi barrado acima), deixa passar!
        if (path.startsWith('/empresa/')) {
          print('✅ [PERMISSÃO] Fluxo de Empresa detectado. Acesso liberado.');
          return null;
        }

        // Se NÃO está ativo e não está na tela de completar cadastro, joga pra lá
        if (!isAtivo && path != '/completar-cadastro') {
          print(
            '➡️ [DESVIO] Usuário inativo fora do fluxo. Indo para: /completar-cadastro',
          );
          return '/completar-cadastro';
        }

        // Se ESTÁ ativo e tentar acessar telas iniciais, joga pra Projetos
        if (isAtivo &&
            (path == '/completar-cadastro' ||
                path == '/' ||
                path == '/login' ||
                path.startsWith('/register'))) {
          print(
            '➡️ [DESVIO] Usuário ativo em tela de entrada. Indo para: /projetos',
          );
          return '/projetos';
        }
      }
      return null;
    },

    routes: [
      // --- ROTAS PÚBLICAS / AUTH ---
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/perfis',
        builder: (context, state) => const Scaffold(
          body: SizedBox.shrink(),
        ),
        routes: [
          GoRoute(
            path: 'perfil_dados',
            builder: (context, state) =>
                PerfilScreen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil_minha_conta',
            builder: (context, state) =>
                PerfilMinhaConta(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil_notificacoes',
            builder: (context, state) => const PerfilNotificacoes(),
          ),
          GoRoute(
            path: 'perfil_privacidade',
            builder: (context, state) => const PerfilMinhaPrivacidade(),
          ),
          GoRoute(
            path: 'perfil_central_ajuda',
            builder: (context, state) => const PerfilCentralAjuda(),
          ),
        ],
      ),
      // --- FLUXO DE CADASTRO ACADÊMICO E CLIENTE ---
      GoRoute(
        path: '/register',
        builder: (context, state) => const CadastroR0Screen(),
        routes: [
          GoRoute(
            path: 'dados',
            builder: (context, state) =>
                CadastroR1Screen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'perfil',
            builder: (context, state) =>
                CadastroR2Screen(dadosCadastro: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'academico',
            builder: (context, state) => CadastroAcademicoScreen(
              dadosCadastro: _routeExtra(state.extra),
            ),
          ),
          GoRoute(
            path: 'cliente/gate',
            builder: (context, state) =>
                Cadastro0Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'cliente/checkboxes',
            builder: (context, state) =>
                Cadastro1Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          GoRoute(
            path: 'cliente/planos',
            builder: (context, state) =>
                Cadastro2Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
          // Mantido caso precise de fallback, mas o fluxo normal agora pula pro /empresa/cadastro
          GoRoute(
            path: 'cliente/welcome',
            builder: (context, state) =>
                Cadastro3Cliente(dadosUsuario: _routeExtra(state.extra)),
          ),
        ],
      ),

      // --- FLUXO DE ONBOARDING EMPRESA (FORA DO SHELL) ---
      GoRoute(
        path: '/empresa/gate',
        builder: (context, state) =>
            Cadastro0Empresa(dadosCadastro: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: '/empresa/onboarding',
        builder: (context, state) =>
            Cadastro1Empresa(dadosCadastro: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, state) => const RecuperaSenhaScreen(),
      ),
      GoRoute(
        path: '/nova-senha',
        builder: (context, state) => const NovaSenhaScreen(),
      ),
      GoRoute(
        path: '/empresa/servicos',
        builder: (context, state) =>
            Cadastro2Empresa(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: '/empresa/planos',
        builder: (context, state) =>
            Cadastro3Empresa(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: '/empresa/cadastro',
        builder: (context, state) {
          // LÊ OS DADOS DA MEMÓRIA DO RIVERPOD 
          final dadosSalvos = ref.read(rascunhoCadastroProvider);
          return EmpresaCadastroScreen(dadosUsuario: dadosSalvos);
        },
      ),
      GoRoute(
        path: '/empresa/bemvinda',
        builder: (context, state) =>
            EmpresaBemVindaScreen(dadosUsuario: _routeExtra(state.extra)),
      ),
      GoRoute(
        path: '/completar-cadastro',
        builder: (context, state) => const CompletarCadastroScreen(),
      ),

      // --- ÁREA LOGADA (SHELL ROUTE COM RODAPÉ) ---
      GoRoute(
        path: '/estruturas/:estruturaId/elementos/:elementoId',
        builder: (context, state) {
          final extra = _routeExtra(state.extra);
          return ElementosHomeScreen(
            estruturaId: state.pathParameters['estruturaId'],
            elementoId: state.pathParameters['elementoId'],
            projetoId: _stringExtra(extra, 'projetoId'),
            titulo: _stringExtra(extra, 'titulo'),
            tipo: _stringExtra(extra, 'tipo'),
            local: _stringExtra(extra, 'local'),
            imageUrl: _stringExtra(extra, 'imageUrl'),
          );
        },
        routes: [
          GoRoute(
            path: 'informacoes',
            builder: (context, state) {
              final extra = _routeExtra(state.extra);
              final basePath =
                  '/estruturas/${state.pathParameters['estruturaId']}/elementos/${state.pathParameters['elementoId']}';
              return ElementoInfoScreen(
                initialNome: _stringExtra(extra, 'titulo') ?? 'ABC Corp.',
                initialTipoElemento: _elementoTipo(extra),
                initialTipologiaEstrutural: _elementoTipologia(extra),
                initialLocalElemento: _stringExtra(extra, 'local'),
                onOpenRelatorios: () =>
                    context.push('$basePath/relatorios', extra: extra),
              );
            },
          ),
          GoRoute(
            path: 'relatorios',
            builder: (context, state) {
              final extra = _routeExtra(state.extra);
              final basePath =
                  '/estruturas/${state.pathParameters['estruturaId']}/elementos/${state.pathParameters['elementoId']}';
              return RelatoriosScreen(
                onOpenInformacoes: () =>
                    context.push('$basePath/informacoes', extra: extra),
              );
            },
          ),
        ],
      ),

      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // Projetos e suas sub-rotas
          GoRoute(
            path: '/projetos',
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: 'detalhes',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => ProjectDetailScreen(
                  projetoId: state.extra as String? ?? '',
                ),
              ),
            ],
          ),
          // Outras abas da Bottom Bar
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const EstruturasTabScreen(),
          ),
          GoRoute(
            path: '/minha-empresa',
            builder: (context, state) =>
                const EmpresaScreen(),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Educação'))),
          ),
          GoRoute(
            path: '/notificacoes',
            builder: (context, state) => const NotificacoesScreen(),
          ),
        ],
      ),
    ],
  );
});
