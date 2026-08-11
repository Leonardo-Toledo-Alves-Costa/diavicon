import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/empresa_model.dart';

class EmpresaRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  
  Future<String> salvarEmpresa({
    required Map<String, dynamic> dadosEmpresa,
    required String userId,
  }) async {
    //  Salva o endereço comercial (Criando o registro na tabela enderecos)
    final enderecoData = await _supabase
        .from('enderecos')
        .insert({
          'endereco': dadosEmpresa['rua'], 
          'cidade': dadosEmpresa['cidade'],
          'estado': dadosEmpresa['estado'],
          'cep': dadosEmpresa['cep'],
          'bairro': dadosEmpresa['bairro'],
          'numero': dadosEmpresa['numero'],
          'complemento': dadosEmpresa['complemento'], 
          'pais': 'Brasil',
        })
        .select('id')
        .single();

    final String idEndereco = enderecoData['id'];

    // Faz o Upload da Foto para o Storage 
    String? fotoUrlPublica;
    final String? fotoPathLocal = dadosEmpresa['fotoPath']; 
    
    if (fotoPathLocal != null && fotoPathLocal.isNotEmpty) {
      try {
        final arquivoFoto = File(fotoPathLocal);
        final extensao = fotoPathLocal.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final caminhoStorage = 'empresas/$timestamp.$extensao';

        await _supabase.storage.from('avatars').upload(caminhoStorage, arquivoFoto);
        fotoUrlPublica = _supabase.storage.from('avatars').getPublicUrl(caminhoStorage);
      } catch (e) {
        // Rethrow para o erro aparecer na tela do cadastro
        throw Exception('Falha ao fazer upload da logo da empresa. Verifique as policies do bucket "avatars". Erro: $e');
      }
    }

    //  Formata o CNPJ e salva a empresa (VINCULANDO O ENDEREÇO)
    final String cnpjLimpo = dadosEmpresa['cnpj'].replaceAll(RegExp(r'[^0-9]'), '');
    final String cnpjFormatado = cnpjLimpo.length == 14
        ? '${cnpjLimpo.substring(0, 2)}.${cnpjLimpo.substring(2, 5)}.${cnpjLimpo.substring(5, 8)}/${cnpjLimpo.substring(8, 12)}-${cnpjLimpo.substring(12, 14)}'
        : dadosEmpresa['cnpj'];

    final empresaData = await _supabase
        .from('empresas')
        .insert({
          'nome': dadosEmpresa['nome'],
          'cnpj': cnpjFormatado,
          'plano_id': dadosEmpresa['plano_id'],
          'tamanho': dadosEmpresa['colaboradores'],
          'tipo': dadosEmpresa['tipo'], 
          'ativo': true,
          'foto_url': fotoUrlPublica,
          'site': dadosEmpresa['site'], 
          'linkedin': dadosEmpresa['linkedin'],
          'endereco_id': idEndereco, 
        })
        .select('id')
        .single();

    final String idEmpresa = empresaData['id'];

    //  Atualiza o usuário 
    await _supabase
        .from('usuarios')
        .update({
          'empresa_id': idEmpresa,
          'cargo': dadosEmpresa['cargo'],
          'titulo_principal': dadosEmpresa['nivel'],
          'is_admin_empresa': true,
        })
        .eq('id', userId);

    return idEmpresa;
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
