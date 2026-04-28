import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Auth & Cadastro de Usuário ──────────────────────────────────────────────
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';

// ── Onboarding da Empresa ───────────────────────────────────────────────────
import '../../features/auth/screens/cadastro0_empresa.dart';
import '../../features/auth/screens/cadastro1_empresa.dart';
import '../../features/auth/screens/cadastro2_empresa.dart';
import '../../features/auth/screens/cadastro3_empresa.dart';

// ── Home / Projetos / Core ──────────────────────────────────────────────────
import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final usuario = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuario != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',

    // REDIRECT: Proteção de rotas (Auth Guard)
    redirect: (context, state) {
      final path = state.uri.toString();
      
      // Define rotas públicas: Login, Cadastro e Onboarding completo
      final bool isPublic = path == '/' || 
                           path == '/login' || 
                           path.startsWith('/register') || 
                           path.startsWith('/empresa');

      if (!isLoggedIn && !isPublic) return '/login';
      
      if (isLoggedIn && (path == '/' || path == '/login' || path.startsWith('/register') || path.startsWith('/empresa'))) {
        return '/projetos';
      }
      return null;
    },

    routes: [
      // ── ROTAS PÚBLICAS (FORA DO RODAPÉ) ────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── FLUXO DE CADASTRO DE USUÁRIO ──────────────────────────────────────
      GoRoute(
        path: '/register',
        builder: (context, state) => const CadastroR0Screen(),
        routes: [
          GoRoute(
            path: 'dados', // /register/dados
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR1Screen(
                email: extra['email'] ?? '',
                senha: extra['senha'] ?? '',
              );
            },
          ),
          GoRoute(
            path: 'perfil', // /register/perfil
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR2Screen(dadosUsuario: extra);
            },
          ),
          GoRoute(
            path: 'academico', // /register/academico
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroAcademicoScreen(dadosUsuario: extra);
            },
          ),
        ],
      ),

      // ── FLUXO DE ONBOARDING DA EMPRESA ────────────────────────────────────
      // IMPORTANTE: Todas aqui extraem o 'extra' para não quebrar a corrente
      GoRoute(
        path: '/empresa/gate',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return Cadastro0Empresa(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/onboarding',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return Cadastro1Empresa(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/servicos',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return Cadastro2Empresa(dadosUsuario: extra);
        },
      ),
      GoRoute(
        path: '/empresa/planos',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return Cadastro3Empresa(dadosUsuario: extra);
        },
      ),

      // ── ÁREA LOGADA (SHELL ROUTE COM RODAPÉ) ──────────────────────────────
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MainScreen(child: child),
        routes: [
          // ABA PROJETOS
          GoRoute(
            path: '/projetos',
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: 'detalhes',
                builder: (context, state) {
                  final id = state.extra as String?;
                  if (id == null) {
                    return const Scaffold(
                      body: Center(child: Text('Erro: ID do projeto não encontrado.')),
                    );
                  }
                  return ProjectDetailScreen(projetoId: id);
                },
              ),
            ],
          ),

          // ABA ESTRUTURAS
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Tela de Estruturas')),
            ),
          ),

          // ABA EMPRESA (Perfil/Gestão)
          GoRoute(
            path: '/empresa',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Perfil da Empresa')),
            ),
          ),

          // ABA EDUCAÇÃO
          GoRoute(
            path: '/educacao',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Área de Educação')),
            ),
          ),
        ],
      ),
    ],
  );
});