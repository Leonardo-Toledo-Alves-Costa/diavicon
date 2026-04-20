import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final currentUserProvider = 
    StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  return CurrentUserNotifier();
});

final authControllerProvider = 
    StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});

class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) {
    state = user;
  }

  void clearUser() {
    state = null;
  }
}

class AuthController extends StateNotifier<bool> {
  final Ref _ref;

  AuthController(this._ref) : super(false);

  Future<void> login(String email, String password) async {
    state = true; 
    try {
      final repo = _ref.read(authRepositoryProvider);
      final response = await repo.signIn(email, password);

      if (response.user != null) {
        final perfil = await repo.getUsuarioPerfil(response.user!.id);
        _ref.read(currentUserProvider.notifier).setUser(perfil!);
      }
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }
}