import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';

// ── Empresa ───────────────────────────────────────────────────────────────────
import '../../features/empresa/screens/empresa_gate_screen.dart';
import '../../features/empresa/screens/empresa_onboarding_screen.dart';
import '../../features/empresa/screens/empresa_servicos_screen.dart';
import '../../features/empresa/screens/empresa_planos_screen.dart';
import '../../features/empresa/screens/empresa_cadastro_screen.dart';
import '../../features/empresa/screens/empresa_bemvinda_screen.dart';

// ── Elementos Estruturais ─────────────────────────────────────────────────────
import '../../features/elementos/screens/elementos_screen.dart';

// ── Home / Projetos ───────────────────────────────────────────────────────────
import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';

// ── Auth Provider ─────────────────────────────────────────────────────────────
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final usuarioLogado = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuarioLogado != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',

    redirect: (context, state) {
      final path = state.uri.toString();

      const publicPrefixes = [
        '/',
        '/login',
        '/register',
        '/empresa/gate',
        '/empresa/onboarding',
        '/empresa/servicos',
        '/empresa/planos',
        '/empresa/cadastro',
        '/empresa/bemvinda',
      ];

      final isPublic = publicPrefixes.any(
        (p) => path == p || path.startsWith('$p/'),
      );

      if (!isLoggedIn && !isPublic) return '/login';

      if (isLoggedIn &&
          (path == '/' ||
              path == '/login' ||
              path.startsWith('/register'))) {
        return '/projetos';
      }

      return null;
    },

    routes: [
      // ── TELAS DE AUTH ─────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── CADASTRO DE USUÁRIO ───────────────────────────────────────────────
      GoRoute(
        path: '/register',
        builder: (context, state) => const CadastroR0Screen(),
      ),
      GoRoute(
        path: '/register/dados',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CadastroR1Screen(
            email: extra['email'] as String? ?? '',
            senha: extra['senha'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/register/perfil',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CadastroR2Screen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/register/academico',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CadastroAcademicoScreen(dadosUsuario: extra);
        },
      ),

      // ── FLUXO DE EMPRESA ──────────────────────────────────────────────────
      GoRoute(
        path: '/empresa/gate',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaGateScreen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/onboarding',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaOnboardingScreen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/servicos',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaServicosScreen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/planos',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaPlanosScreen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/cadastro',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaCadastroScreen(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/bemvinda',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmpresaBemVindaScreen(dadosUsuario: extra);
        },
      ),

      // ── TELAS COM RODAPÉ (ShellRoute) ─────────────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          GoRoute(
            path: '/projetos',
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: 'detalhes',
                builder: (context, state) => const ProjectDetailScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const Scaffold(
                body: Center(child: Text('Tela de Estruturas'))),
            routes: [
              // ── Elementos Estruturais ──────────────────────────────────────
              GoRoute(
                path: ':estruturaId/elementos',
                builder: (context, state) {
                  final estruturaId = state.pathParameters['estruturaId']!;
                  final extra =
                      state.extra as Map<String, dynamic>? ?? {};
                  return ElementosScreen(
                    estruturaId: estruturaId,
                    estruturaNome:
                        extra['estruturaNome'] as String? ?? 'Estrutura',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/empresa',
            builder: (context, state) => const Scaffold(
                body: Center(child: Text('Informações da Empresa'))),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) => const Scaffold(
                body: Center(child: Text('Área de Educação'))),
          ),
        ],
      ),
    ],
  );
});