import 'package:diavicon/features/empresa/screens/empresa_bemvinda_screen.dart';
import 'package:diavicon/features/empresa/screens/empresa_cadastro_screen.dart';
import 'package:diavicon/features/projetos/screens/notificacoes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';

import '../../features/auth/screens/cadastro0_empresa.dart';
import '../../features/auth/screens/cadastro1_empresa.dart';
import '../../features/auth/screens/cadastro2_empresa.dart';
import '../../features/auth/screens/cadastro3_empresa.dart';

import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',

    redirect: (context, state) {
      final path = state.uri.toString();
      final bool isLoggedIn = ref.read(currentUserProvider) != null;

      // Redirecionamento para usuários NÃO logados
      if (!isLoggedIn) {
        final bool isPublic =
            path == '/' ||
            path == '/login' ||
            path.startsWith('/register') ||
            path.startsWith('/empresa/');

        if (!isPublic) return '/login';
        return null;
      }

      //  Redirecionamento para usuários logados
      if (isLoggedIn) {
        // Permite continuar no onboarding de empresa sem interrupção
        if (path.startsWith('/empresa/')) {
          return null;
        }

        // Se o usuário já logado tentar acessar telas iniciais, manda para Projetos
        if (path == '/' || path == '/login' || path.startsWith('/register')) {
          return '/projetos';
        }
      }

      return null;
    },

    routes: [
      // --- ROTAS PÚBLICAS / AUTH ---
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      // --- FLUXO DE CADASTRO ACADÊMICO ---
      GoRoute(
        path: '/register',
        builder: (context, state) => const CadastroR0Screen(),
        routes: [
          GoRoute(
            path: 'dados',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR1Screen(
                email: extra['email'] ?? '',
                senha: extra['senha'] ?? '',
              );
            },
          ),
          GoRoute(
            path: 'perfil',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR2Screen(dadosUsuario: extra);
            },
          ),
          GoRoute(
            path: 'academico',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroAcademicoScreen(dadosUsuario: extra);
            },
          ),
        ],
      ),

      // --- FLUXO DE ONBOARDING EMPRESA (FORA DO SHELL) ---
      GoRoute(
        path: '/empresa/gate',
        builder: (context, state) => Cadastro0Empresa(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/empresa/onboarding',
        builder: (context, state) => Cadastro1Empresa(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/empresa/servicos',
        builder: (context, state) => Cadastro2Empresa(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/empresa/planos',
        builder: (context, state) => Cadastro3Empresa(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/empresa/cadastro',
        builder: (context, state) => EmpresaCadastroScreen(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),
      GoRoute(
        path: '/empresa/bemvinda',
        builder: (context, state) => EmpresaBemVindaScreen(
          dadosUsuario: state.extra as Map<String, dynamic>? ?? {},
        ),
      ),

      // --- ÁREA LOGADA (SHELL ROUTE COM BOTTOM BAR) ---
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // Projetos e suas sub-rotas (detalhes)
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
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Estruturas'))),
          ),
          GoRoute(
            path: '/minha-empresa',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Perfil da Empresa'))),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Educação'))),
          ),

          // NOTIICACOES
          GoRoute(
            path: '/notificacoes',
            builder: (context, state) => const NotificacoesScreen(),
          ),
        ],
      ),
    ],
  );
});
