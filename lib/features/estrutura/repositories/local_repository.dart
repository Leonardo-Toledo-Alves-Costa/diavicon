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

  Future<LocalModel> criarLocal(String estruturaId, String nome) async {
    final response = await _client
        .from('estruturas_locais')
        .insert({
          'estrutura_id': estruturaId,
          'nome': nome,
        })
        .select()
        .single();

    return LocalModel.fromMap(response);
  }
}