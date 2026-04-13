


import 'package:diavicon/core/services/auth_service.dart';
import 'package:diavicon/features/home/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  //chaves globais pra gerenciar estado de nav
  static final _rootNavigatiorkey = GlobalKey<NavigatorState>();
  static final _shellNavigatiorkey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    navigatorKey: _rootNavigatiorkey,
    refreshListenable: authService,

    redirect: (context, state) {
      final bool loggedIn = authService.isLoggedIn;
      
      // qual tela o usuário está tentando ir
      final bool isGoingToAuthScreen = state.uri.toString() == '/login' || 
                                       state.uri.toString() == '/register';

      if (!loggedIn && !isGoingToAuthScreen) {
        return '/login';
      }

      if (loggedIn && isGoingToAuthScreen) {
        return '/projetos';
      }

      return null;
    },

    routes: [
      //fora do rodape
      GoRoute(
      path: '/login',
      builder: (context, state) => const Placeholder()//LoginScreen();
      ),
      GoRoute(
      path: '/register',
      builder: (context, state) => const Placeholder()//RegisterScreen();
      ),

      //com rodape
      ShellRoute(
        navigatorKey: _shellNavigatiorkey,
        builder: (context, state, child) {
          //o chield é a aba selecionada

          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
          path: '/estruturas',
          builder: (context, state) => Placeholder()//ListaProjetosScreen(),
          ),
          GoRoute(
            path: '/estruturas',
            builder: (context, state) => const Center(child: Text('Estruturas')),
          ),
          GoRoute(
            path: '/empresa',
            builder: (context, state) => const Center(child: Text('Empresa')),
          ),
          GoRoute(
            path: '/educacao',
            builder: (context, state) => const Center(child: Text('Educação')),
          ),
        ],
        // protecao de rotas (implementar)
        redirect: (context, state) {
          
          return null;
        },
      ),
    ]
  );
}