import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends StateNotifier<bool> {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthController(this._ref) : super(false);

  Future<void> login(String email, String password) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final response = await repo.signIn(email, password);

      if (response.user != null) {
        final perfil = await repo.getUsuarioPerfil(response.user!.id);
        if (perfil != null) {
          _ref.read(currentUserProvider.notifier).setUser(perfil);
        }
      }
    } finally {
      state = false;
    }
  }

  // MÉTODO DE CADASTRO
  Future<void> registrar({
    required String email,
    required String password,
    required Map<String, dynamic> dados,
  }) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.signUp(
        email: email,
        password: password,
        dadosCompletos: dados,
      );

      final userAuth = repo.currentUser;
      if (userAuth != null) {
        final perfil = await repo.getUsuarioPerfil(userAuth.id);
        if (perfil != null) {
          _ref.read(currentUserProvider.notifier).setUser(perfil);
        }
      }
    } finally {
      state = false;
    }
  }

  Future<void> autenticarComGoogle(BuildContext context) async {
    try {
      
      const webClientId = '138394999909-367jt3c0vud0ms2hjieml3l36ujs8oss.apps.googleusercontent.com'; 
      const iosClientId = '138394999909-31bt8545tpt5p0dba1c3ht9hobfprhld.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn.instance;
      
      // 1. Inicializa o SDK
      await googleSignIn.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      // Abre a tela do Google
      final googleUser = await googleSignIn.authenticate();
      
      // Pega a Identidade (idToken)
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      // A SOLUÇÃO DO ERRO: Pega as Permissões separadamente (accessToken)
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);
      final accessToken = clientAuth.accessToken;

      if (idToken == null) {
        throw 'Erro ao obter token do Google.';
      }

      // Autentica no Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Erro interno de autenticação.';

      // Verifica se o usuário tem perfil cadastrado manualmente
      final repo = _ref.read(authRepositoryProvider);
      final perfilCompleto = await repo.getUsuarioPerfil(user.id);

      if (perfilCompleto != null) {
        // PERFIL EXISTE: Injeta no app e vai pra Home
        _ref.read(currentUserProvider.notifier).setUser(perfilCompleto);
        
        if (context.mounted) {
          context.go('/projetos');
        }
      } else {
        //BARRADO: Não tem perfil. Desloga e avisa na tela.
        await _supabase.auth.signOut();
        await googleSignIn.signOut();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail não cadastrado. Faça o cadastro manual primeiro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login cancelado ou erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}