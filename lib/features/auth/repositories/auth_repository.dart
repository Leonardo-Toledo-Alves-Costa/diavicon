import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Login
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // lib/features/auth/repositories/auth_repository.dart
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> dadosCompletos,
  }) async {
    // 1. Cria apenas a credencial de login
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // 2. Salva APENAS o perfil básico do humano na tabela 'usuarios'
      await _supabase.from('usuarios').insert({
        'id': response.user!.id,
        'nome': dadosCompletos['nome'],
        'sobrenome': dadosCompletos['sobrenome'],
        'email': email,
        'celular': dadosCompletos['telefone'],
        'perfil': dadosCompletos['perfil'], // 'Empresa'
        'ativo': true,
      });
    }
  }

  // Busca perfil
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    final data = await _supabase
        .from('usuarios')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UsuarioModel.fromMap(data);
  }

  // Logout
  Future<void> signOut() async => await _supabase.auth.signOut();

  // Pega a sessão atual (para o app abrir já logado)
  User? get currentUser => _supabase.auth.currentUser;
}
