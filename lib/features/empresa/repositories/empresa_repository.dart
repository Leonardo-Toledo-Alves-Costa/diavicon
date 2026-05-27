import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/empresa_model.dart';

class EmpresaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Salva a empresa no Supabase e vincula ao usuário
  /// Fluxo:
  ///   1. Insere endereço na tabela 'enderecos' → pega o ID.
  ///   2. Insere empresa na tabela 'empresas' vinculado ao endereço.
  ///   3. Atualiza o perfil do usuário na tabela 'usuarios' com o ID da empresa.
  Future<String> salvarEmpresa({
    required Map<String, dynamic>
    dadosEmpresa, // Recebe o mapa 'empresa' da Screen
    required String userId,
  }) async {
    // Salva o endereço comercial
    final enderecoData = await _supabase
        .from('enderecos')
        .insert({
          'endereco': dadosEmpresa['rua'],
          'cidade': dadosEmpresa['cidade'],
          'estado': dadosEmpresa['estado'],
          'cep': dadosEmpresa['cep'],
          'bairro': dadosEmpresa['bairro'],
          'numero': dadosEmpresa['numero'],
          'pais': 'Brasil',
        })
        .select('id')
        .single();

    final String idEndereco = enderecoData['id'];

    // Salva a empresa com os dados corretos
    final empresaData = await _supabase
        .from('empresas')
        .insert({
          'nome': dadosEmpresa['nome'],
          'cnpj': dadosEmpresa['cnpj'],
          'plano_id': dadosEmpresa['plano_id'],
          'tamanho': dadosEmpresa['colaboradores'],
          'ativo': true,
        })
        .select('id')
        .single();

    final String idEmpresa = empresaData['id'];

    // Atualiza o usuário com o ID da empresa
    await _supabase
        .from('usuarios')
        .update({
          'empresa_id': idEmpresa,
          'cargo': dadosEmpresa['cargo'],
          'titulo_principal': dadosEmpresa['nivel'],
        })
        .eq('id', userId);

    return idEmpresa;
  }

  /// Busca os dados da empresa para manter no estado global do app
  Future<EmpresaModel?> getEmpresa(String empresaId) async {
    try {
      final data = await _supabase
          .from('empresas')
          .select()
          .eq('id', empresaId)
          .maybeSingle();

      if (data == null) return null;
      return EmpresaModel.fromMap(data);
    } catch (e) {
      print("Erro ao buscar empresa: $e");
      return null;
    }
  }
}
