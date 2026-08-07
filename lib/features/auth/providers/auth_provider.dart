import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../repositories/auth_repository.dart';
import '../controller/auth_controller.dart';

// Provider do Repositório (Acesso ao Banco)
final authRepositoryProvider = Provider((ref) => AuthRepository());

// 🔥 ATUALIZADO: O Provider agora se auto-inicializa e escuta o Supabase Auth
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, UsuarioModel?>((ref) {
  final notifier = CurrentUserNotifier();
  notifier.sincronizarSessaoAtiva(); // Busca o perfil imediatamente se houver token
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
  CurrentUserNotifier() : super(null);

  void setUser(UsuarioModel user) => state = user;
  void clearUser() => state = null;

  //  Método que salva o app-onboarding de usuários pré-cadastrados/convidados
  Future<void> sincronizarSessaoAtiva() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user != null) {
      try {
        // Busca os dados do perfil direto na sua tabela pública de usuários
        final response = await Supabase.instance.client
            .from('usuarios')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (response != null) {
          state = UsuarioModel.fromMap(response); // Popula o Riverpod em tempo real!
        }
      } catch (e) {
        state = null; // Falha de consistência limpa o estado com segurança
      }
    }
  }
}