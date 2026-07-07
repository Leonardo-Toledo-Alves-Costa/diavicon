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
      final resposta = await Supabase.instance.client
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

      // Transforma a resposta do banco de dados no LocalModel atualizado
      return LocalModel.fromMap(resposta); 
      
    } catch (e) {
      throw Exception('Erro ao criar local no banco de dados: $e');
    }
  }
}