import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Importe as telas reais que fizemos
import '../../features/auth/screens/login_screen.dart';
import '../../features/projetos/screens/projetos_screen.dart';
import '../../features/home/screens/main_screen.dart'; // O seu Shell
import '../../features/auth/providers/auth_provider.dart'; // O Provider de Auth!

// Transformamos o Router em um Provider para ele enxergar o estado de login
final routerProvider = Provider<GoRouter>((ref) {
  
  // O Router fica "assistindo" o usuário. Se ele ficar null, o router bloqueia o app.
  final usuarioLogado = ref.watch(currentUserProvider);
  final bool isLoggedIn = usuarioLogado != null;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/login',
    
    // A LÓGICA DE PROTEÇÃO QUE VOCÊ CRIOU (Agora conectada ao Riverpod)
    redirect: (context, state) {
      final isGoingToAuthScreen = state.uri.toString() == '/login' || 
                                  state.uri.toString() == '/register';

      // Se não tá logado e tá tentando ir pra dentro do app -> Manda pro Login
      if (!isLoggedIn && !isGoingToAuthScreen) {
        return '/login';
      }

      // Se já tá logado e tá tentando ir pra tela de Login/Register -> Manda pra Home
      if (isLoggedIn && isGoingToAuthScreen) {
        return '/projetos';
      }

      return null; // Deixa seguir viagem
    },

    routes: [
      // FORA DO RODAPÉ
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(), // A tela que fizemos!
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Cadastro'))),
      ),

      // COM RODAPÉ (ShellRoute)
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/projetos', // Corrigido (antes estava estruturas duplicado)
            builder: (context, state) => const ProjetosScreen(), // A tela conectada ao BD!
          ),
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