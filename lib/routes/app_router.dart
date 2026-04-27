import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Importações das suas telas
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/projetos/screens/project_detail_screen.dart';
import '../../features/home/screens/main_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Assiste o estado do usuário para o Auth Guard
  final usuarioLogado = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuarioLogado != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',

    // REDIRECT: Proteção de rotas (Auth Guard)
    redirect: (context, state) {
      final isWelcome = state.uri.toString() == '/';
      final isLogin = state.uri.toString() == '/login';
      final isRegister = state.uri.toString() == '/register';

      final isPublicRoute = isWelcome || isLogin || isRegister;

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn && isPublicRoute) {
        return '/projetos';
      }

      return null;
    },

    routes: [
      // --- ROTAS FORA DO RODAPÉ ---
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const Placeholder(),
      ),

      // --- ROTAS COM RODAPÉ (SHELL ROUTE) ---
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [
          // ABA PROJETOS
          GoRoute(
            path: '/projetos',
            builder: (context, state) => const ProjetosScreen(),
            routes: [
              GoRoute(
                path: 'detalhes', // Fica /projetos/detalhes
                builder: (context, state) {
                  // AQUI ESTÁ O SEGREDO:
                  // Recuperamos o objeto passado no extra. 
                  // No ProjectCard, você deve usar: context.push('/projetos/detalhes', extra: projeto.id);
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

          // OUTRAS ABAS
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const Scaffold(body: Center(child: Text('Estruturas'))),
          ),
          GoRoute(
            path: '/empresa',
            builder: (context, state) => const Scaffold(body: Center(child: Text('Empresa'))),
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