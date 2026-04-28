import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// --- Auth & Cadastro ---
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/cadastro_r0_screen.dart';
import '../../features/auth/screens/cadastro_r1_screen.dart';
import '../../features/auth/screens/cadastro_r2_screen.dart';
import '../../features/auth/screens/cadastro_academico_screen.dart';

// --- Onboarding Empresa ---
import '../../features/auth/screens/cadastro0_empresa.dart';
import '../../features/auth/screens/cadastro1_empresa.dart';
import '../../features/auth/screens/cadastro2_empresa.dart';
import '../../features/auth/screens/cadastro3_empresa.dart';

// --- Core ---
import '../../features/home/screens/main_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final usuarioLogado = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuarioLogado != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',

    // REDIRECT: Proteção de rotas (Auth Guard)
    redirect: (context, state) {
      final path = state.uri.toString();
      
      // Rotas que não precisam de login (Cadastro e Onboarding inclusos)
      final bool isPublicRoute = path == '/' || 
                                 path == '/login' || 
                                 path.startsWith('/register') || 
                                 path.startsWith('/empresa');

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn && isPublicRoute) {
        return '/projetos';
      }

      return null;
    },

    routes: [
      // --- ROTAS PÚBLICAS (FORA DO RODAPÉ) ---
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // --- FLUXO DE CADASTRO (Sub-rotas para manter organização) ---
      GoRoute(
        path: '/register',
        builder: (context, state) => const CadastroR0Screen(),
        routes: [
          GoRoute(
            path: 'dados', // vira /register/dados
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR1Screen(
                email: extra['email'] ?? '',
                senha: extra['senha'] ?? '',
              );
            },
          ),
          GoRoute(
            path: 'perfil', // vira /register/perfil
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroR2Screen(dadosUsuario: extra);
            },
          ),
          GoRoute(
            path: 'academico', // vira /register/academico
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>? ?? {};
              return CadastroAcademicoScreen(dadosUsuario: extra);
            },
          ),
        ],
      ),

      // --- FLUXO ONBOARDING EMPRESA ---
      GoRoute(
        path: '/empresa/gate',
        builder: (context, state) => const Cadastro0Empresa(),
      ),
      GoRoute(
        path: '/empresa/onboarding',
        builder: (context, state) => const Cadastro1Empresa(),
      ),
      GoRoute(
        path: '/empresa/servicos',
        builder: (context, state) => const Cadastro2Empresa(),
      ),
      GoRoute(
        path: '/empresa/planos',
        builder: (context, state) => const Cadastro3Empresa(),
      ),

      // --- ÁREA LOGADA (SHELL ROUTE) ---
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
                builder: (context, state) {
                  final id = state.extra as String?;
                  if (id == null) {
                    return const Scaffold(body: Center(child: Text('Erro: ID não encontrado.')));
                  }
                  return ProjectDetailScreen(projetoId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const Scaffold(body: Center(child: Text('Estruturas'))),
          ),
          GoRoute(
            path: '/empresa', // Perfil da empresa pós-login
            builder: (context, state) => const Scaffold(body: Center(child: Text('Perfil Empresa'))),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) => const Scaffold(body: Center(child: Text('Educação'))),
          ),
        ],
      ),
    ],
  );
});