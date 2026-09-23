import 'dart:async';
import 'package:diavicon/core/services/storage_urls.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show PaintingBinding;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import '../controller/auth_controller.dart';
import '../utils/auth_error_messages.dart';

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

/// Por que a sessão foi encerrada, quando não foi a pessoa que pediu.
///
/// A tela de entrada mostra este texto, para quem foi suspenso no meio do uso
/// não ficar sem entender por que caiu.
final avisoAcessoProvider = StateProvider<String?>((ref) => null);

// O perfil e o estado de acesso são atualizados juntos a cada evento do Auth.
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  final notifier = CurrentUserNotifier(ref);
  // Numa microtask, não na hora: a primeira sincronização altera
  // `authAccessStatusProvider` de forma SÍNCRONA quando não há sessão
  // (loading → signedOut), e o Riverpod 3 proíbe um provider alterar outro
  // durante a própria criação ("Providers are not allowed to modify other
  // providers during their initialization"). Em debug isso derrubava o app
  // ao abrir do zero, deslogado; em release o assert some e passava batido.
  Future.microtask(() {
    if (notifier.mounted) unawaited(notifier.sincronizarSessaoAtiva());
  });
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
  Timer? _revisaoPeriodica;
  int _syncGeneration = 0;

  /// De quanto em quanto tempo o app confere se o acesso continua valendo.
  ///
  /// Sem isso, suspender um colaborador só surtia efeito no próximo evento de
  /// auth — a renovação do token, que leva cerca de uma hora. Quem já estava
  /// dentro do app seguia trabalhando normalmente nesse meio tempo.
  static const _intervaloRevisao = Duration(minutes: 5);

  CurrentUserNotifier(this._ref) : super(null) {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(sincronizarSessaoAtiva());
    });
    _revisaoPeriodica = Timer.periodic(_intervaloRevisao, (_) {
      if (Supabase.instance.client.auth.currentSession == null) return;
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

  bool setUserIfSessionMatches(UsuarioModel user) {
    final sessionUserId = Supabase.instance.client.auth.currentUser?.id;
    if (sessionUserId == null || sessionUserId != user.id) return false;

    setUser(user);
    return true;
  }

  void clearUser({AuthAccessStatus status = AuthAccessStatus.signedOut}) {
    _syncGeneration++;
    // Links temporários e imagens privadas da conta anterior não podem
    // ficar em memória para a próxima pessoa que entrar neste aparelho.
    StorageUrls.limparCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
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
      if (state != null) {
        StorageUrls.limparCache();
        PaintingBinding.instance.imageCache.clear();
      }
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
    // Re-sincronização do MESMO usuário (tokenRefreshed a cada ~1h, volta do
    // app do background depois da câmera, userUpdated...) é silenciosa. Antes
    // todo evento de auth passava por `loading`, e o redirect do go_router
    // trata `loading` fora de rota pública como "manda pro /login" — e, com o
    // perfil ativo de volta, do /login pra home. Resultado: o usuário no meio
    // de um registro (ex: inspeção visual salvando 20 fotos) era jogado pra
    // home e perdia a pilha de navegação inteira.
    final mesmoUsuario = state != null && state!.id == user.id;
    if (!mesmoUsuario) setAccessStatus(AuthAccessStatus.loading);
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

      // Acesso suspenso não é só uma tela bloqueada: a sessão cai na hora,
      // para o token parar de valer, e o motivo fica guardado para aparecer
      // na tela de entrada.
      if (perfil.convitePendente != true && perfil.ativo != true) {
        _ref.read(avisoAcessoProvider.notifier).state = mensagemAcessoSuspenso;
        state = null;
        _ref.read(authAccessStatusProvider.notifier).state = AuthAccessStatus.signedOut;
        unawaited(Supabase.instance.client.auth.signOut());
        return;
      }

      state = perfil;
      _ref.read(avisoAcessoProvider.notifier).state = null;
      setAccessStatus(
        perfil.convitePendente == true ? AuthAccessStatus.invitePending : AuthAccessStatus.active,
      );
    } catch (e) {
      // A falha de leitura não abre o shell nem mantém um perfil possivelmente
      // desatualizado em memória.
      //
      // O log importa: este catch roda em background (disparado por qualquer
      // evento de auth) e leva o app pra tela de "auth indisponível" sem que
      // nenhuma tela mostre a causa. Era invisível no diagnóstico do
      // "Salvar e Acessar".
      debugPrint('[Auth] sincronizarSessaoAtiva falhou ao ler o perfil: $e');
      if (generation != _syncGeneration) return;
      // Falha transitória (sem sinal em campo, timeout) numa re-sincronização
      // do mesmo usuário não derruba a sessão que já estava aberta: mantém o
      // perfil carregado e tenta de novo no próximo evento de auth.
      if (mesmoUsuario) return;
      state = null;
      _ref.read(authAccessStatusProvider.notifier).state =
          AuthAccessStatus.unavailable;
    }
  }

  @override
  void dispose() {
    _syncGeneration++;
    _authSubscription?.cancel();
    _revisaoPeriodica?.cancel();
    super.dispose();
  }
}