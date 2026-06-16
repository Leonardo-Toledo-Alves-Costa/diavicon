import 'dart:io';

import 'package:flutter/material.dart';
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

  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> dadosCompletos,
  }) async {
    // Cria apenas a credencial de login
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      String? fotoUrlPublica;
      
      // 🔥 Pega o caminho da foto que veio das telas anteriores do cadastro (Passo 1 ou 2)
      // Ajuste a chave ('fotoPath' ou 'fotoPerfilPath') conforme estiver no seu formulário inicial
      final String? fotoPathLocal = dadosCompletos['fotoPath'] ?? dadosCompletos['fotoPerfilPath'];

      if (fotoPathLocal != null && fotoPathLocal.isNotEmpty) {
        try {
          final arquivoFoto = File(fotoPathLocal);
          final extensao = fotoPathLocal.split('.').last;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final caminhoStorage = 'usuarios/${response.user!.id}_$timestamp.$extensao';

          await _supabase.storage.from('avatars').upload(caminhoStorage, arquivoFoto);
          fotoUrlPublica = _supabase.storage.from('avatars').getPublicUrl(caminhoStorage);
        } catch (e) {
          debugPrint('🚨 ERRO NO UPLOAD DO USUÁRIO: $e');
          throw Exception('Falha ao fazer upload da foto de perfil: $e');
        }
      }

      // Salva o perfil na tabela 'usuarios' incluindo o link da foto
      await _supabase.from('usuarios').insert({
        'id': response.user!.id,
        'nome': dadosCompletos['nome'],
        'sobrenome': dadosCompletos['sobrenome'],
        'email': email,
        'celular': dadosCompletos['telefone'],
        'perfil': dadosCompletos['perfil'], // 'Empresa'
        'foto_url': fotoUrlPublica, // 🔥 AGORA A FOTO VAI SALVA DIRETO NO USUÁRIO!
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

  // ── Recuperação de senha ───────────────────────────────────────────────────

  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'diavicon://nova-senha',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
