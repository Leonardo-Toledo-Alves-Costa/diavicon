import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Faz o login no Supabase Auth
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Busca os dados da tabela 'usuarios' usando o seu UsuarioModel
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    final data = await _supabase
        .from('usuarios')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UsuarioModel.fromMap(data); 
  }

  // Faz o logout
  Future<void> signOut() async => await _supabase.auth.signOut();
}