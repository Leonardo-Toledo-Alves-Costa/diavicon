import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import '../controller/auth_controller.dart';

// Provider do Repositório (Acesso ao Banco)
final authRepositoryProvider = Provider((ref) => AuthRepository());

//  O Provider agora se auto-inicializa e escuta o Supabase Auth
final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
      return CurrentUserNotifier();
    });

// Provider que controla o estado de Loading e ações de Autenticação
final authControllerProvider = StateNotifierProvider<AuthController, bool>((
  ref,
) {
  return AuthController(ref);
});

final fotoUsuarioProvider = FutureProvider.autoDispose<String?>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  // Busca a URL da foto na tabela de usuarios
  final resp = await supabase
      .from('usuarios')
      .select('foto_url')
      .eq('id', userId)
      .maybeSingle();
  return resp?['foto_url'] as String?;
});

// Provider que controla o estado de Loading e ações de Recuperação de Senha
final recuperaSenhaControllerProvider =
    StateNotifierProvider<RecuperaSenhaController, bool>((ref) {
      return RecuperaSenhaController(ref);
    });
// Provider que vai segurar os dados do cadastro na memória do app com segurança
final rascunhoCadastroProvider = StateProvider<Map<String, dynamic>>(
  (ref) => {},
);

// Mantém apenas a transição cadastro da empresa -> boas-vindas aberta enquanto
// o perfil passa a ter empresa_id. Não suspende a proteção de rotas privadas.
final bloqueioDeRotaProvider = StateProvider<bool>((ref) => false);

// Libera o MaterialApp.router somente após a primeira leitura da sessão/perfil.
final authBootstrapCompleteProvider = StateProvider<bool>((ref) => false);

// Notifier inteligente para mutação e sincronização do usuário autenticado
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  int _syncGeneration = 0;

  void setUser(UsuarioModel user) {
    _syncGeneration++;
    state = user;
  }

  bool setUserIfSessionMatches(UsuarioModel user) {
    if (Supabase.instance.client.auth.currentSession?.user.id != user.id) {
      return false;
    }
    setUser(user);
    return true;
  }

  void clearUser() {
    _syncGeneration++;
    state = null;
  }

  //  Método que salva o app-onboarding de usuários pré-cadastrados/convidados
  Future<void> sincronizarSessaoAtiva() async {
    final generation = ++_syncGeneration;
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (generation == _syncGeneration) state = null;
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('id', session.user.id)
          .maybeSingle();

      final currentSession = Supabase.instance.client.auth.currentSession;
      if (generation != _syncGeneration ||
          currentSession?.user.id != session.user.id) {
        return;
      }

      state = response == null ? null : UsuarioModel.fromMap(response);
    } catch (_) {
      // Uma falha transitória não equivale a logout. Mantemos o último perfil;
      // signedOut continua sendo a única fonte que limpa uma sessão existente.
    }
  }
}
