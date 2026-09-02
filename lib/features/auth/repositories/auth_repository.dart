import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/uuid_generator.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // Realiza a autenticação direta por senha
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Executa o isolamento de credenciais e realiza o upload assíncrono da foto de perfil
  Future<void> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> dadosCompletos,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      if (response.session == null) {
        throw Exception(
          'Cadastro criado. Confirme seu e-mail antes de continuar.',
        );
      }

      String? fotoUrlPublica;
      final String? fotoPathLocal =
          dadosCompletos['fotoPath'] ?? dadosCompletos['fotoPerfilPath'];

      if (fotoPathLocal != null && fotoPathLocal.isNotEmpty) {
        try {
          final arquivoFoto = File(fotoPathLocal);
          final extensao = fotoPathLocal.split('.').last;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final caminhoStorage = 'usuarios/${user.id}_$timestamp.$extensao';

          await _supabase.storage
              .from('avatars')
              .upload(caminhoStorage, arquivoFoto);
          fotoUrlPublica = _supabase.storage
              .from('avatars')
              .getPublicUrl(caminhoStorage);
        } catch (e) {
          debugPrint('🚨 [ERRO STORAGE AVATAR]: $e');
          throw Exception(
            'Falha ao processar upload da foto de perfil contratada: $e',
          );
        }
      }
      final String idEndereco = UuidGenerator.v4();
      await _supabase.from('enderecos').insert({
        'id': idEndereco,
        // Certifique-se que as chaves ('rua', 'cidade', etc) batem com o que vem do front
        'endereco': dadosCompletos['rua'],
        'cidade': dadosCompletos['cidade'],
        'estado': dadosCompletos['estado'],
        'cep': dadosCompletos['cep'],
        'bairro': dadosCompletos['bairro'],
        'numero': dadosCompletos['numero'],
        'complemento': dadosCompletos['complemento'],
        'pais': 'Brasil',
      });

      // Persiste a estrutura de dados de segurança na tabela pública de usuários
      await _supabase.from('usuarios').insert({
        'id': user.id,
        'nome': dadosCompletos['nome'],
        'sobrenome': dadosCompletos['sobrenome'],
        'email': email,
        'celular': dadosCompletos['telefone'],
        'perfil': dadosCompletos['perfil'],
        'foto_url': fotoUrlPublica,
        'endereco_id': idEndereco,
      });
    }
  }

  // Recupera as informações estendidas mapeadas no banco relacional
  Future<UsuarioModel?> getUsuarioPerfil(String userId) async {
    final data = await _supabase
        .from('usuarios')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return UsuarioModel.fromMap(data);
  }

  Future<void> salvarPerfil(UsuarioModel usuario) async {
    await _supabase
        .from('usuarios')
        .update(usuario.toMap())
        .eq('id', usuario.id);
  }

  Future<void> signOut() async => await _supabase.auth.signOut();

  // ── LÓGICA DE RECUPERAÇÃO DE CREDENCIAIS (SUPABASE AUTH) ─────────────────

  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'diavicon://nova-senha',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
