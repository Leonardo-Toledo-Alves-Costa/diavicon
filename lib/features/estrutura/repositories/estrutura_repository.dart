import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estrutura_model.dart';

class EstruturaRepository {
  final SupabaseClient _client;

  EstruturaRepository(this._client);

  /// Cria uma nova estrutura e já vincula ao projeto correspondente
  Future<void> criarEstrutura(
    EstruturaModel estrutura,
    String projetoId,
  ) async {
    try {
      //Insere na tabela 'estruturas' e recupera o ID gerado pelo banco
      final response = await _client
          .from('estruturas')
          .insert(estrutura.toMap())
          .select()
          .single();

      final String novaEstruturaId = response['id'];

      // Cria o vínculo na tabela associativa 'projeto_estruturas'
      await _client.from('projeto_estruturas').insert({
        'projeto_id': projetoId,
        'estrutura_id': novaEstruturaId,
      });
    } catch (e) {
      throw Exception('Falha ao registrar estrutura: $e');
    }
  }

  /// Busca todas as estruturas vinculadas a um projeto específico
  Future<List<EstruturaModel>> buscarEstruturasPorProjeto(
    String projetoId,
  ) async {
    try {
      // Realiza o join através da tabela de relacionamento
      final response = await _client
          .from('projeto_estruturas')
          .select('estruturas (*)')
          .eq('projeto_id', projetoId);

      return (response as List)
          .where((item) => item['estruturas'] != null)
          .map((item) => EstruturaModel.fromMap(item['estruturas']))
          .toList();
    } catch (e) {
      throw Exception('Erro ao carregar lista de estruturas: $e');
    }
  }
}
