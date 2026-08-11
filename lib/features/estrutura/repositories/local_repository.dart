import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_model.dart';

class LocalRepository {
  final SupabaseClient _client;

  LocalRepository(this._client);

  Future<List<LocalModel>> buscarLocais(String estruturaId) async {
    final response = await _client
        .from('estruturas_locais')
        .select()
        .eq('estrutura_id', estruturaId)
        .order('nome', ascending: true);

    return (response as List).map((item) => LocalModel.fromMap(item)).toList();
  }

  Future<LocalModel> criarLocal({
    required String estruturaId,
    required String nome,
    String? tipologia,
    String? condicao,
    String? descricao,
  }) async {
    try {
      final resposta = await _client
          .from('estruturas_locais')
          .insert({
            'estrutura_id': estruturaId,
            'nome': nome,
            'tipologia': tipologia,
            'condicao_exposicao': condicao,
            'descricao': descricao,
          })
          .select()
          .single();

      return LocalModel.fromMap(resposta); 
      
    } catch (e) {
      throw Exception('Erro ao criar local no banco de dados: $e');
    }
  }

  Future<void> criarTipologiaLocal(String nome, String empresaId) async {
    await _client.from('tipologias_local').insert({
      'nome': nome,
      'empresa_id': empresaId,
    });
  }

  Future<void> criarCondicaoLocal(String nome, String empresaId) async {
    await _client.from('condicoes_local').insert({
      'nome': nome,
      'empresa_id': empresaId,
    });
  }
}