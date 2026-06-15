import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/elemento_model.dart';

/// Acesso à tabela `elementos_estruturais` no Supabase.
///
/// Um elemento sempre pertence a uma estrutura (`estrutura_id`).
class ElementoRepository {
  final SupabaseClient _client;

  ElementoRepository(this._client);

  /// Cria um elemento vinculado a uma estrutura e devolve o registro criado.
  Future<ElementoModel> criarElemento(
    ElementoModel elemento,
    String estruturaId,
  ) async {
    try {
      final map = elemento.toMap();
      map['estrutura_id'] = estruturaId;

      final response = await _client
          .from('elementos_estruturais')
          .insert(map)
          .select()
          .single();

      return ElementoModel.fromMap(response);
    } catch (e) {
      throw Exception('Falha ao criar elemento: $e');
    }
  }

  /// Lista os elementos ativos de uma estrutura, mais recentes primeiro.
  Future<List<ElementoModel>> buscarElementosPorEstrutura(
    String estruturaId,
  ) async {
    try {
      final response = await _client
          .from('elementos_estruturais')
          .select()
          .eq('estrutura_id', estruturaId)
          .order('criado_em', ascending: false);

      return (response as List)
          .map((item) => ElementoModel.fromMap(item))
          .toList();
    } catch (e) {
      throw Exception('Erro ao carregar elementos: $e');
    }
  }

  /// Atualiza um elemento existente (identificado pelo `id`).
  Future<ElementoModel> atualizarElemento(ElementoModel elemento) async {
    try {
      final response = await _client
          .from('elementos_estruturais')
          .update(elemento.toMap())
          .eq('id', elemento.id)
          .select()
          .single();

      return ElementoModel.fromMap(response);
    } catch (e) {
      throw Exception('Falha ao atualizar elemento: $e');
    }
  }

  /// Soft delete: marca o elemento como inativo em vez de apagá-lo.
  Future<void> desativarElemento(String elementoId) async {
    try {
      await _client
          .from('elementos_estruturais')
          .update({'ativo': false})
          .eq('id', elementoId);
    } catch (e) {
      throw Exception('Falha ao desativar elemento: $e');
    }
  }
}
