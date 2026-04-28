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
  // 1. Cria no Supabase Auth
  final response = await _supabase.auth.signUp(email: email, password: password);

  if (response.user != null) {
    // 2. SALVA O ENDEREÇO (conforme sua tabela 'enderecos')
    final enderecoData = await _supabase.from('enderecos').insert({
      'endereco': dadosCompletos['rua'],
      'cidade': dadosCompletos['cidade'],
      'estado': dadosCompletos['estado'],
      'cep': dadosCompletos['cep'],
      'pais': 'Brasil',
    }).select('id').single();

    final String idEndereco = enderecoData['id'];

    // 3. SALVA O USUÁRIO (conforme sua tabela 'usuarios')
    await _supabase.from('usuarios').insert({
      'id': response.user!.id,
      'nome': dadosCompletos['nome'],
      'sobrenome': dadosCompletos['sobrenome'],
      'email': email,
      'celular': dadosCompletos['telefone'], // Nome no banco é 'celular'
      'ativo': true,
      // Se você adicionou a coluna endereco_id na tabela usuarios, descomente:
      // 'endereco_id': idEndereco, 
    });
    
    // 4. SE FOR EMPRESA: Salva na tabela empresas também
    if (dadosCompletos['perfil'] == 'Empresa') {
      await _supabase.from('empresas').insert({
        'nome': dadosCompletos['nome_empresa'] ?? dadosCompletos['nome'],
        'cnpj': dadosCompletos['cnpj'],
        'endereco_id': idEndereco, // Aqui o vínculo é essencial!
        'plano_id': dadosCompletos['plano_id'], // ID do plano escolhido
        'ativo': true,
      });
    }
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
