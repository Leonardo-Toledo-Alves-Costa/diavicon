import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import '../controller/auth_controller.dart';

// Provider do Repositório (Acesso ao Banco)
final authRepositoryProvider = Provider((ref) => AuthRepository());

enum AuthAccessStatus {
  loading,
  signedOut,
  awaitingEmailConfirmation,
  registrationPending,
  invitePending,
  active,
  inactive,
  unavailable,
}

final authAccessStatusProvider =
    StateProvider<AuthAccessStatus>((ref) => AuthAccessStatus.loading);

// O perfil e o estado de acesso são atualizados juntos a cada evento do Auth.
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  final notifier = CurrentUserNotifier(ref);
  unawaited(notifier.sincronizarSessaoAtiva());
  return notifier;
});

// Provider que controla o estado de Loading e ações de Autenticação
final authControllerProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});

final fotoUsuarioProvider = FutureProvider.autoDispose<String?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  // Busca a URL da foto na tabela de usuarios
  final resp = await supabase.from('usuarios').select('foto_url').eq('id', userId).maybeSingle();
  return resp?['foto_url'] as String?;
});

// Provider que controla o estado de Loading e ações de Recuperação de Senha
final recuperaSenhaControllerProvider = StateNotifierProvider<RecuperaSenhaController, bool>((ref) {
  return RecuperaSenhaController(ref);
});
// Provider que vai segurar os dados do cadastro na memória do app com segurança
final rascunhoCadastroProvider = StateProvider<Map<String, dynamic>>((ref) => {});

//  FLAG DE SEGURANÇA: Se estiver true, o roteador não chuta ninguém de tela!
final bloqueioDeRotaProvider = StateProvider<bool>((ref) => false);

// Notifier inteligente para mutação e sincronização do usuário autenticado
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  final Ref _ref;
  StreamSubscription<AuthState>? _authSubscription;
  int _syncGeneration = 0;

  CurrentUserNotifier(this._ref) : super(null) {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(sincronizarSessaoAtiva());
    });
  }

  void setUser(UsuarioModel user) {
    _syncGeneration++;
    state = user;
    _ref.read(authAccessStatusProvider.notifier).state =
        user.ativo == true
            ? AuthAccessStatus.active
            : user.convitePendente == true
                ? AuthAccessStatus.invitePending
                : AuthAccessStatus.inactive;
  }

  void clearUser({AuthAccessStatus status = AuthAccessStatus.signedOut}) {
    _syncGeneration++;
    state = null;
    _ref.read(authAccessStatusProvider.notifier).state = status;
  }

  void setAccessStatus(AuthAccessStatus status) {
    _ref.read(authAccessStatusProvider.notifier).state = status;
  }

  // Carrega somente a linha do próprio usuário; não há leitura por e-mail.
  Future<void> sincronizarSessaoAtiva() async {
    final generation = ++_syncGeneration;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      state = null;
      _ref.read(authAccessStatusProvider.notifier).state =
          AuthAccessStatus.signedOut;
      return;
    }

    final user = session.user;
    if (user.emailConfirmedAt == null) {
      if (generation != _syncGeneration) return;
      state = null;
      _ref.read(authAccessStatusProvider.notifier).state =
          AuthAccessStatus.awaitingEmailConfirmation;
      return;
    }

    if (generation != _syncGeneration) return;
    setAccessStatus(AuthAccessStatus.loading);
    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (generation != _syncGeneration) return;
      if (response == null) {
        state = null;
        _ref.read(authAccessStatusProvider.notifier).state =
            AuthAccessStatus.registrationPending;
        return;
      }

      final perfil = UsuarioModel.fromMap(response);
      state = perfil;
      final status = perfil.convitePendente == true
          ? AuthAccessStatus.invitePending
          : perfil.ativo == true
              ? AuthAccessStatus.active
              : AuthAccessStatus.inactive;
      setAccessStatus(status);
    } catch (_) {
      // A falha de leitura não abre o shell nem mantém um perfil possivelmente
      // desatualizado em memória.
      if (generation != _syncGeneration) return;
      state = null;
      _ref.read(authAccessStatusProvider.notifier).state =
          AuthAccessStatus.unavailable;
    }
  }

  @override
  void dispose() {
    _syncGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
