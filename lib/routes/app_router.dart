import 'package:diavicon/features/projetos/screens/project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Importe suas telas reais
import '../../features/auth/screens/welcome_screen.dart'; // Tela inicial
import '../../features/auth/screens/login_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/home/screens/main_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Assiste o estado do usuário para reagir a logins/logouts automaticamente
  final usuarioLogado = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuarioLogado != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/', // O app agora começa na WelcomeScreen

    // REFRESH LISTENER: Faz o GoRouter reavaliar o redirecionamento quando o estado de auth muda
    // Se o seu authProvider não for um ChangeNotifier, você pode precisar de um listener customizado.
    redirect: (context, state) {
      // Definimos quais são as rotas públicas (que não precisam de login)
      final isWelcome = state.uri.toString() == '/';
      final isLogin = state.uri.toString() == '/login';
      final isRegister = state.uri.toString() == '/register';

      final isPublicRoute = isWelcome || isLogin || isRegister;

      // 1. Caso: Usuário NÃO está logado e tenta acessar rota privada
      if (!isLoggedIn && !isPublicRoute) {
        return '/login'; // Manda pro login
      }

      // 2. Caso: Usuário JÁ está logado e tenta acessar rotas de Auth
      // Se ele já logou, não precisa mais ver a Welcome, Login ou Register
      if (isLoggedIn && isPublicRoute) {
        return '/projetos'; // Manda direto para a tela principal
      }

      return null; // Mantém a navegação atual
    },

    routes: [
      // --- ROTAS FORA DO RODAPÉ (TELA CHEIA) ---
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const WelcomeScreen(), // Sua nova tela inicial
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            const Placeholder(), // Certifique-se de que a tela existe
      ),

      // --- ROTAS COM RODAPÉ (SHELL ROUTE) ---
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainScreen(child: child); // O MainScreen contém o BottomAppBar
        },
        routes: [
          GoRoute(
            path: '/projetos',
            builder: (context, state) =>
                const ProjetosScreen(), // Tela conectada ao Supabase
            routes: [
              GoRoute(
                path: 'detalhes', // Fica /projetos/detalhes
                builder: (context, state) => const ProjectDetailScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/estruturas',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Tela de Estruturas'))),
          ),
          GoRoute(
            path: '/empresa',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Informações da Empresa')),
            ),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Área de Educação'))),
          ),
        ],
      ),
    ],
  );
});
