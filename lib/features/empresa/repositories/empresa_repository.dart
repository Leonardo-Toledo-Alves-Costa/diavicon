import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/empresa_model.dart';

class EmpresaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Salva a empresa no Supabase e vincula ao usuário
  /// Fluxo:
  ///   1. Insere endereço na tabela 'enderecos' → pega o ID.
  ///   2. Insere empresa na tabela 'empresas' vinculado ao endereço.
  ///   3. Atualiza o perfil do usuário na tabela 'usuarios' com o ID da empresa e PODER DE ADMIN.
  Future<String> salvarEmpresa({
    required Map<String, dynamic> dadosEmpresa,
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
    final String cnpjLimpo = dadosEmpresa['cnpj'].replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final String cnpjFormatado = cnpjLimpo.length == 14
        ? '${cnpjLimpo.substring(0, 2)}.${cnpjLimpo.substring(2, 5)}.${cnpjLimpo.substring(5, 8)}/${cnpjLimpo.substring(8, 12)}-${cnpjLimpo.substring(12, 14)}'
        : dadosEmpresa['cnpj']; // Fallback se não for 14 dígitos

    // Salva a empresa com o CNPJ padronizado
    final empresaData = await _supabase
        .from('empresas')
        .insert({
          'nome': dadosEmpresa['nome'],
          'cnpj': cnpjFormatado, // 🔥 Sempre formatado!
          'plano_id': dadosEmpresa['plano_id'],
          'tamanho': dadosEmpresa['colaboradores'],
          'ativo': true,
        })
        .select('id')
        .single();

    final String idEmpresa = empresaData['id'];

    // Atualiza o usuário com o ID da empresa e a chave mestra de ADMIN
    await _supabase
        .from('usuarios')
        .update({
          'empresa_id': idEmpresa,
          'cargo': dadosEmpresa['cargo'],
          'titulo_principal': dadosEmpresa['nivel'],
          'is_admin_empresa': true, // 🔥 O PODER SUPREMO É INJETADO AQUI
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
