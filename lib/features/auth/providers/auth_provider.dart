import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import '../controller/auth_controller.dart';

// Provider do Repositório (Acesso ao Banco)
final authRepositoryProvider = Provider((ref) => AuthRepository());

// Provider que guarda o estado do Usuário Logado no App
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  return CurrentUserNotifier();
});

// Provider que controla o estado de Loading e ações de Autenticação
final authControllerProvider = StateNotifierProvider<AuthController, bool>((ref) {
  return AuthController(ref);
});

// Provider que controla o estado de Loading e ações de Recuperação de Senha
final recuperaSenhaControllerProvider = StateNotifierProvider<RecuperaSenhaController, bool>((ref) {
  return RecuperaSenhaController(ref);
});

// Notifier puro para mutação do usuário autenticado
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;
}