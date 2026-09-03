import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../repositories/auth_operations_repository.dart';
import '../utils/auth_error_messages.dart';

// ── CONTROLLER PRINCIPAL DE AUTENTICAÇÃO ──────────────────────────────────
class AuthController extends StateNotifier<bool> {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthController(this._ref) : super(false);

  // Login tradicional por e-mail e senha
  Future<void> login(String email, String password) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final response = await repo.signIn(email, password);

      if (response.user != null) {
        await _ref.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
      }
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // Cadastro unificado de usuários e fluxo de dados corporativos
  Future<bool> registrar({
    required String email,
    required String password,
    required Map<String, dynamic> dados,
  }) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);
      final existingSession = _supabase.auth.currentSession;
      if (existingSession != null &&
          existingSession.user.email?.toLowerCase() == email.toLowerCase()) {
        if (existingSession.user.emailConfirmedAt == null) {
          _ref
              .read(currentUserProvider.notifier)
              .setAccessStatus(AuthAccessStatus.awaitingEmailConfirmation);
          return false;
        }
        await _ref.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
        return true;
      }

      if (password.isEmpty) {
        throw Exception('Informe sua senha para iniciar o cadastro.');
      }
      final response = await repo.signUp(email: email, password: password);
      if (response.session == null || response.user?.emailConfirmedAt == null) {
        _ref
            .read(currentUserProvider.notifier)
            .setAccessStatus(AuthAccessStatus.awaitingEmailConfirmation);
        return false;
      }
      await _ref.read(currentUserProvider.notifier).sincronizarSessaoAtiva();
      return true;
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  Future<void> autenticarComGoogle(BuildContext context) async {
    state = true;
    try {
      const webClientId = '138394999909-367jt3c0vud0ms2hjieml3l36ujs8oss.apps.googleusercontent.com'; 
      const iosClientId = '138394999909-31bt8545tpt5p0dba1c3ht9hobfprhld.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn.instance;
      
      await googleSignIn.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.authenticate(); 

      final googleAuth = googleUser.authentication;
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

      final currentUserNotifier = _ref.read(currentUserProvider.notifier);
      await currentUserNotifier.sincronizarSessaoAtiva();
      final accessStatus = _ref.read(authAccessStatusProvider);
      if (accessStatus == AuthAccessStatus.registrationPending) {
        final cleanup = await AuthOperationsRepository().execute(
          'cleanup_google_orphan',
          const {},
        );
        await _supabase.auth.signOut();
        if (cleanup['excluida'] == true) {
          currentUserNotifier.clearUser();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail não cadastrado na plataforma. Efetue o cadastro manual primeiro.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      if (accessStatus == AuthAccessStatus.active && context.mounted) {
        context.go('/projetos');
      } else if (accessStatus == AuthAccessStatus.invitePending && context.mounted) {
        context.go('/completar-cadastro');
      } else if (accessStatus == AuthAccessStatus.inactive && context.mounted) {
        context.go('/conta-inativa');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authErrorMessage(e, fallback: 'Falha na autenticação.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      state = false;
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
