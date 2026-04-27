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

  // ── Login ──────────────────────────────────────────────────────────────────
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

  // ── Cadastro ───────────────────────────────────────────────────────────────
  /// Cria o usuário no Supabase Auth e salva o perfil na tabela 'usuarios'.
  /// [dados] é o Map acumulado ao longo das telas R0 → R1.
  Future<void> register(Map<String, dynamic> dados) async {
    state = true;
    try {
      final repo = _ref.read(authRepositoryProvider);

      // 1. Cria o usuário no Supabase Auth
      final response = await repo.signUp(
        dados['email'] as String,
        dados['senha'] as String,
      );

      if (response.user == null) {
        throw Exception('Erro ao criar usuário.');
      }

      final userId = response.user!.id;

      // 2. Monta o model com os dados das telas R1
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

      // 3. Salva o perfil na tabela 'usuarios'
      await repo.salvarPerfil(usuario);

      // 4. Atualiza o provider com o usuário logado
      _ref.read(currentUserProvider.notifier).setUser(usuario);
    } catch (e) {
      rethrow;
    } finally {
      state = false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.signOut();
    _ref.read(currentUserProvider.notifier).clearUser();
  }
}