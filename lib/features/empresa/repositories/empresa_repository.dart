import 'dart:io';

import 'package:flutter/material.dart';
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
    // 1. Salva o endereço comercial (Criando o registro na tabela enderecos)
    final enderecoData = await _supabase
        .from('enderecos')
        .insert({
          // Certifique-se que as chaves ('rua', 'cidade', etc) batem com o que vem do front
          'endereco': dadosEmpresa['rua'], 
          'cidade': dadosEmpresa['cidade'],
          'estado': dadosEmpresa['estado'],
          'cep': dadosEmpresa['cep'],
          'bairro': dadosEmpresa['bairro'],
          'numero': dadosEmpresa['numero'],
          'complemento': dadosEmpresa['complemento'], // Adicionei complemento que faltava
          'pais': 'Brasil',
        })
        .select('id')
        .single();

    final String idEndereco = enderecoData['id'];

    // 2. Faz o Upload da Foto para o Storage (Mantive sua lógica que tá certa)
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
        debugPrint('🚨 ERRO NO UPLOAD DA EMPRESA: $e');
        // Rethrow para o erro aparecer na tela do cadastro
        throw Exception('Falha ao fazer upload da logo da empresa. Verifique as policies do bucket "avatars". Erro: $e');
      }
    }

    // 3. Formata o CNPJ e salva a empresa (VINCULANDO O ENDEREÇO)
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
          'tipo': dadosEmpresa['tipo'], // Mantenha o tipo vindo do controller
          'ativo': true,
          'foto_url': fotoUrlPublica,
          'site': dadosEmpresa['site'], // Adicionei campos opcionais que faltavam
          'linkedin': dadosEmpresa['linkedin'],
          
          // 🔥 A CORREÇÃO ESTÁ AQUI! 🔥
          // Vincula a empresa ao ID do endereço que acabamos de criar acima.
          'endereco_id': idEndereco, 
        })
        .select('id')
        .single();

    final String idEmpresa = empresaData['id'];

    // 4. Atualiza o usuário (Mantive sua lógica que tá certa)
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
          // 👇 Fazemos um "Join" para puxar a cidade e o estado da tabela 'enderecos'
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
