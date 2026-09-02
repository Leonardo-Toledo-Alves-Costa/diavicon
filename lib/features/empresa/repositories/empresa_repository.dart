import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/repositories/auth_operations_repository.dart';
import '../models/empresa_model.dart';

class EmpresaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> salvarEmpresa({
    required Map<String, dynamic> dadosEmpresa,
    required String userId,
  }) async {
    // Faz o Upload da Foto para o Storage
    String? fotoUrlPublica;
    final String? fotoPathLocal = dadosEmpresa['fotoPath'];

    if (fotoPathLocal != null && fotoPathLocal.isNotEmpty) {
      try {
        final arquivoFoto = File(fotoPathLocal);
        final extensao = fotoPathLocal.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final caminhoStorage = 'empresas/$timestamp.$extensao';

        await _supabase.storage
            .from('avatars')
            .upload(caminhoStorage, arquivoFoto);
        fotoUrlPublica = _supabase.storage
            .from('avatars')
            .getPublicUrl(caminhoStorage);
      } catch (e) {
        // Rethrow para o erro aparecer na tela do cadastro
        throw Exception(
          'Falha ao fazer upload da logo da empresa. Verifique as policies do bucket "avatars". Erro: $e',
        );
      }
    }

    final result = await AuthOperationsRepository().execute('create_company', {
      'dados_empresa': {
        'nome': dadosEmpresa['nome'],
        'cnpj': dadosEmpresa['cnpj'],
        'plano_id': dadosEmpresa['plano_id'],
        'tamanho': dadosEmpresa['colaboradores'],
        'tipo': dadosEmpresa['tipo'],
        'foto_url': fotoUrlPublica,
        'site': dadosEmpresa['site'],
        'linkedin': dadosEmpresa['linkedin'],
        'rua': dadosEmpresa['rua'],
        'cidade': dadosEmpresa['cidade'],
        'estado': dadosEmpresa['estado'],
        'cep': dadosEmpresa['cep'],
        'bairro': dadosEmpresa['bairro'],
        'numero': dadosEmpresa['numero'],
        'complemento': dadosEmpresa['complemento'],
      },
      'cargo': dadosEmpresa['cargo'],
      'titulo_principal': dadosEmpresa['nivel'],
    });

    return result['empresa_id'] as String;
  }

  /// Busca os dados da empresa para manter no estado global do app
  Future<EmpresaModel?> getEmpresa(String empresaId) async {
    try {
      final data = await _supabase
          .from('empresas')
          .select('*, enderecos(cidade, estado)')
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
