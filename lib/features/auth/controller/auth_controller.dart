import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';

// ── CONTROLLER PRINCIPAL DE AUTENTICAÇÃO ──────────────────────────────────
class AuthController extends StateNotifier<bool> {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  AuthController(this._ref) : super(false) {
    _escutarMudancasDeSessao();
  }

  void _escutarMudancasDeSessao() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      debugPrint("⚡ [AUTH EVENTO DETECTADO]: $event");

      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) && session?.user != null) {
        try {
          final repo = _ref.read(authRepositoryProvider);
          final perfil = await repo.getUsuarioPerfil(session!.user!.id);
          
          if (perfil != null) {
            _ref.read(currentUserProvider.notifier).setUser(perfil);
          } else {
            debugPrint("🚨 [ERRO]: Usuário autenticado no Auth, mas perfil não encontrado na tabela 'usuarios'.");
          }
        } catch (e) {
          debugPrint("🚨 [ERRO AO CARREGAR SESSÃO]: $e");
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _ref.read(currentUserProvider.notifier).clearUser();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // Login tradicional por e-mail e senha
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
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // Cadastro unificado de usuários e fluxo de dados corporativos
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
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // Autenticação via Google com verificação de segurança de perfil existente
  Future<void> autenticarComGoogle(BuildContext context) async {
    try {
      const webClientId = '138394999909-367jt3c0vud0ms2hjieml3l36ujs8oss.apps.googleusercontent.com'; 
      const iosClientId = '138394999909-31bt8545tpt5p0dba1c3ht9hobfprhld.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn.instance;
      
      await googleSignIn.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.authenticate();
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);
      final accessToken = clientAuth.accessToken;

      if (idToken == null) throw 'Erro ao obter token do Google.';

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) throw 'Erro interno de autenticação.';

      final repo = _ref.read(authRepositoryProvider);
      final perfilCompleto = await repo.getUsuarioPerfil(user.id);

      if (perfilCompleto != null) {
        _ref.read(currentUserProvider.notifier).setUser(perfilCompleto);
        if (context.mounted) {
          context.go('/projetos');
        }
      } else {
        await _supabase.auth.signOut();
        await googleSignIn.signOut();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail não cadastrado na plataforma. Efetue o cadastro manual primeiro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na autenticação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> logout() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.signOut();
    _ref.read(currentUserProvider.notifier).clearUser();
  }
}

// ── CONTROLLER DE RECUPERAÇÃO DE SENHA ────────────────────────────────────
class RecuperaSenhaController extends StateNotifier<bool> {
  final Ref _ref;

  RecuperaSenhaController(this._ref) : super(false);

  // Dispara o e-mail contendo o deep link cadastrado
  Future<void> enviarLink(String email) async {
    state = true;
    try {
      await _ref.read(authRepositoryProvider).resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // Atualiza a credencial do usuário ativo através do token de segurança
  Future<void> atualizarSenha(String novaSenha) async {
    state = true;
    try {
      await _ref.read(authRepositoryProvider).updatePassword(novaSenha);
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }
}