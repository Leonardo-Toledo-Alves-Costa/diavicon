import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Cadastro: cria usuário no Supabase Auth ────────────────────────────────
  Future<AuthResponse> signUp(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // ── Salva dados do perfil na tabela 'usuarios' ────────────────────────────
  Future<void> salvarPerfil(UsuarioModel usuario) async {
    await _supabase.from('usuarios').upsert(usuario.toMap());
  }

  // ── Busca perfil do usuário na tabela 'usuarios' ──────────────────────────
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    final data = await _supabase
        .from('usuarios')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UsuarioModel.fromMap(data);
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> signOut() async => await _supabase.auth.signOut();
}