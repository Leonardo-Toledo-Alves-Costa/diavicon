import 'package:diavicon/features/auth/controller/auth_controller.dart';
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

//Notifier do usuário logado 
class CurrentUserNotifier extends StateNotifier<UsuarioModel?> {
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;
}

