import 'dart:io'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/elemento_model.dart';

class ElementoRepository {
  final SupabaseClient _client;

  ElementoRepository(this._client);

  Future<ElementoModel> criarElemento(
    ElementoModel elemento,
    String estruturaId,
  ) async {
    try {
      final map = elemento.toMap();
      map['estrutura_id'] = estruturaId;

      if (map['planta_id'] == null || map['planta_id'] == '') map.remove('planta_id');
      if (map['local_id'] == null || map['local_id'] == '') map.remove('local_id');

      final response = await _client
          .from('elementos_estruturais')
          .insert(map)
          .select();

      if (response.isEmpty) {
        throw Exception('Permissão negada ao tentar criar o elemento.');
      }

      return ElementoModel.fromMap(response.first);
    } catch (e) {
      throw Exception('Falha ao criar elemento: $e');
    }
  }

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

  Future<ElementoModel> atualizarElemento(ElementoModel elemento) async {
    try {
      final map = elemento.toMap();
      
      map.remove('id');
      map.remove('criado_em');
      map.remove('estrutura_id');
      
      if (map['planta_id'] == null || map['planta_id'] == '') map.remove('planta_id');
      if (map['local_id'] == null || map['local_id'] == '') map.remove('local_id');

      final response = await _client
          .from('elementos_estruturais')
          .update(map)
          .eq('id', elemento.id)
          .select(); 

      if (response.isEmpty) {
        throw Exception('Permissão negada (RLS) ou elemento não encontrado no banco de dados.');
      }

      return ElementoModel.fromMap(response.first);
    } catch (e) {
      throw Exception('Falha ao atualizar elemento: $e');
    }
  }

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

  Future<void> definirInclusao(String elementoId, bool incluido) async {
    try {
      await _client
          .from('elementos_estruturais')
          .update({'ativo': incluido})
          .eq('id', elementoId);
    } catch (e) {
      throw Exception('Falha ao atualizar inclusão do elemento: $e');
    }
  }

  Future<String> uploadFoto({
    required String elementoId,
    required String caminhoLocalFoto,
  }) async {
    final nomeArquivo =
        '$elementoId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final arquivoFisico = File(caminhoLocalFoto);

    await _client.storage
        .from('elementos-fotos')
        .upload(nomeArquivo, arquivoFisico); 

    return _client.storage
        .from('elementos-fotos')
        .getPublicUrl(nomeArquivo);
  }


  // --- TIPOS DE ELEMENTO ---
  
  Future<List<String>> buscarTiposElemento(List<String> empresasIds) async {
    //if (empresasIds == null) return []; // Se não tem empresa logada, não busca nada
    try {
      final response = await _client
          .from('tipos_elemento')
          .select('nome')
          .inFilter('empresa_id', empresasIds) 
          .order('nome', ascending: true);
          
      return (response as List).map((e) => e['nome'] as String).toList();
    } catch (e) {
      throw Exception('Erro ao carregar Tipos de Elemento: $e');
    }
  }

  Future<void> criarTipoElemento(String nome, String formato, String? empresaId) async {
    try {
      await _client.from('tipos_elemento').insert({
        'nome': nome,
        'formato_marcacao': formato,
        'empresa_id': ?empresaId,
      });
    } catch (e) {
      throw Exception('Falha ao criar Tipo de Elemento: $e');
    }
  }

  // --- TIPOLOGIAS ESTRUTURAIS ---
  
  Future<List<String>> buscarTipologiasElemento(List<String>empresasIds) async {
    //if (empresasIds == null) return [];
    try {
      final response = await _client
          .from('tipologias_elemento')
          .select('nome')
          .inFilter('empresa_id', empresasIds) 
          .order('nome', ascending: true);
      
      return (response as List).map((e) => e['nome'] as String).toList();
    } catch (e) {
      throw Exception('Erro ao carregar Tipologias: $e');
    }
  }

  Future<void> criarTipologiaElemento(String nome, String empresaId) async {
    try {
      await _client.from('tipologias_elemento').insert({
        'nome': nome,
        'empresa_id': empresaId,
      });
    } catch (e) {
      throw Exception('Falha ao criar Tipologia: $e');
    }
  }

  // --- REVESTIMENTOS ---
  
  Future<List<String>> buscarRevestimentosElemento(List<String> empresasIds) async {
    //if (empresasIds == null) return [];
    try {
      final response = await _client
          .from('revestimentos_elemento')
          .select('nome')
          .inFilter('empresa_id', empresasIds) 
          .order('nome', ascending: true);
      
      return (response as List).map((e) => e['nome'] as String).toList();
    } catch (e) {
      throw Exception('Erro ao carregar Revestimentos: $e');
    }
  }

  Future<void> criarRevestimentoElemento(String nome, String empresaId) async {
    try {
      await _client.from('revestimentos_elemento').insert({
        'nome': nome,
        'empresa_id': empresaId,
      });
    } catch (e) {
      throw Exception('Falha ao criar Revestimento: $e');
    }
  }
}