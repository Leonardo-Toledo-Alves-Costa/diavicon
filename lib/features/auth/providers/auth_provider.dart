import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

// Provider que guarda o Usuário Logado
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  return CurrentUserNotifier();
});

// Provider que controla o estado de Loading e as ações
final authControllerProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});

// ── Notifier do usuário logado ─────────────────────────────────────────────
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;
  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;
}

// ── Controller de autenticação ─────────────────────────────────────────────
class AuthController extends StateNotifier<bool> {
  final Ref _ref;

  AuthController(this._ref) : super(false);

  // MÉTODO DE LOGIN
  Future<void> login(String email, String password) async {
    state = true;
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
      
      // Após cadastrar, fazemos o login automático ou buscamos o perfil
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

  // LOGOUT
  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).signOut();
    _ref.read(currentUserProvider.notifier).clearUser();
  }
}