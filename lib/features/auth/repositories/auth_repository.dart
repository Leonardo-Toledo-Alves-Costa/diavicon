import 'package:diavicon/core/security/upload_seguro.dart';
import '../../../core/services/links_auth.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import 'auth_operations_repository.dart';
import '../utils/destino_confirmacao_email.dart';

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

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: destinoConfirmacaoEmail(),
    );
  }

  Future<void> resendSignupConfirmation(String email) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: destinoConfirmacaoEmail(),
    );
  }

  Future<Map<String, dynamic>> completeSelfRegistration({
    required String profileType,
    required Map<String, dynamic> dados,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.emailConfirmedAt == null) {
      throw Exception('Confirme o e-mail antes de concluir o cadastro.');
    }

    String? fotoUrl;
    final fotoPath = dados['fotoPath'] ?? dados['fotoPerfilPath'];
    if (fotoPath is String && fotoPath.isNotEmpty && await File(fotoPath).exists()) {
      try {
        // usuarios/<uid>_<uuid>.<ext>: a política do bucket exige o uid no início.
        final caminho = await _supabase.storage
            .from('avatars')
            .enviarArquivoSeguro('usuarios', File(fotoPath), prefixo: '${user.id}_');
        fotoUrl = _supabase.storage.from('avatars').getPublicUrl(caminho);
      } catch (e) {
        debugPrint('[AUTH] erro ao enviar foto do perfil: $e');
        throw Exception('Falha ao processar a foto de perfil: $e');
      }
    }

    final empresa = dados['empresa'];
    final empresaPayload = empresa is Map
        ? <String, dynamic>{
            'nome': empresa['nome'],
            'cnpj': empresa['cnpj'],
            'tamanho': empresa['colaboradores'],
            'tipo': empresa['tipo'],
            'foto_url': empresa['foto_url'],
            'site': empresa['site'],
            'linkedin': empresa['linkedin'],
            'instagram': empresa['instagram'],
            'email_contato': empresa['email_contato'],
            'whatsapp': empresa['whatsapp'],
            'youtube': empresa['youtube'],
            'ramo_atuacao': empresa['ramo_atuacao'],
            'foto_capa': empresa['foto_capa'],
            'sobre': empresa['sobre'],
            'endereco': {
              'endereco': empresa['rua'],
              'cidade': empresa['cidade'],
              'estado': empresa['estado'],
              'cep': empresa['cep'],
              'bairro': empresa['bairro'],
              'numero': empresa['numero'],
              'complemento': empresa['complemento'],
              'pais': empresa['pais'] ?? 'Brasil',
            },
          }
        : null;
    final profile = <String, dynamic>{
      'nome': dados['nome'],
      'sobrenome': dados['sobrenome'],
      'celular': dados['telefone'] ?? dados['celular'],
      'perfil': dados['perfil'],
      'escolaridade': dados['escolaridade'],
      'formacao': dados['formacao'],
      'cargo': empresa is Map ? empresa['cargo'] : dados['cargo'],
      'titulo_principal': empresa is Map ? empresa['nivel'] : dados['titulo_principal'],
      'foto_url': fotoUrl,
    };
    final address = <String, dynamic>{
      'endereco': dados['rua'],
      'cidade': dados['cidade'],
      'estado': dados['estado'],
      'cep': dados['cep'],
      'bairro': dados['bairro'],
      'numero': dados['numero'],
      'complemento': dados['complemento'],
      'pais': dados['pais'] ?? 'Brasil',
    };
    return AuthOperationsRepository().execute('complete_self_registration', {
      'perfil_tipo': profileType,
      'perfil': profile,
      'endereco': address,
      if (empresaPayload != null) 'empresa': empresaPayload,
    });
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
      redirectTo: destinoNovaSenha,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
