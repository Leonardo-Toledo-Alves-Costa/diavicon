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

// ── Recuperação de senha ───────────────────────────────────────────────────
final recuperaSenhaControllerProvider =
    StateNotifierProvider<RecuperaSenhaController, bool>((ref) {
  return RecuperaSenhaController(ref);
});

// ── Notifier do usuário logado ─────────────────────────────────────────────
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;
}

// ── Controller de autenticação ─────────────────────────────────────────────
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

  Future<void> register(Map<String, dynamic> dados) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);

      final response = await repo.signUp(
        dados['email'] as String,
        dados['senha'] as String,
      );

      if (response.user == null) throw Exception('Erro ao criar usuário.');

      final userId = response.user!.id;

      final usuario = UsuarioModel(
        id: userId,
        nome: dados['nome'] as String?,
        sobrenome: dados['sobrenome'] as String?,
        email: dados['email'] as String?,
        celular: dados['telefone'] as String?,
        cargo: dados['cargo'] as String?,
        tituloPrincipal: dados['formacao'] as String?,
        escolaridade: dados['escolaridade'] as String?,
        ativo: true,
      );

      await repo.salvarPerfil(usuario);
      _ref.read(currentUserProvider.notifier).setUser(usuario);
    } catch (e) {
      rethrow;
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

// ── Controller de recuperação de senha ────────────────────────────────────
class RecuperaSenhaController extends StateNotifier<bool> {
  final Ref _ref;

  RecuperaSenhaController(this._ref) : super(false); // state = isLoading

  /// Envia email com link de recuperação.
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

  /// Atualiza a senha do usuário autenticado via link.
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