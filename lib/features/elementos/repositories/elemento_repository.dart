import 'package:diavicon/core/services/foto_metadados.dart';
import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/elemento_model.dart';

class ElementoRepository {
  static const Map<String, dynamic> marcacaoRemovidaPatch = {
    'planta_id': null,
    'posicao_x': null,
    'posicao_y': null,
    'tipo_marcacao': null,
    'marcacao_largura': null,
    'marcacao_altura': null,
    'marcacao_rotacao': null,
    'marcacao_cor': null,
    'marcacao_nome_x': null,
    'marcacao_nome_y': null,
    'marcacao_imagem_url': null,
  };

  final SupabaseClient _client;

  ElementoRepository(this._client);

  Future<ElementoModel> criarElemento(
    ElementoModel elemento,
    String estruturaId,
  ) async {
    try {
      final map = elemento.toMap();
      map['estrutura_id'] = estruturaId;

      if (map['planta_id'] == null || map['planta_id'] == '')
        map.remove('planta_id');
      if (map['local_id'] == null || map['local_id'] == '')
        map.remove('local_id');

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

      if (map['planta_id'] == null || map['planta_id'] == '')
        map.remove('planta_id');
      if (map['local_id'] == null || map['local_id'] == '')
        map.remove('local_id');

      final response = await _client
          .from('elementos_estruturais')
          .update(map)
          .eq('id', elemento.id)
          .select();

      if (response.isEmpty) {
        throw Exception(
          'Permissão negada (RLS) ou elemento não encontrado no banco de dados.',
        );
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

  Future<void> excluirElemento(String elementoId) async {
    await _client.from('elementos_estruturais').delete().eq('id', elementoId);
  }

  /// Pré-visualização pro sanfonado "o que mais será excluído junto" antes de
  /// confirmar a exclusão do elemento: todos os pontos de ensaio ligados a
  /// ele (ver ON DELETE CASCADE em pontos_ensaios_geral.elemento_estrutural_id).
  Future<Map<String, List<String>>> buscarResumoExclusao(String elementoId) async {
    final res = await _client.from('pontos_ensaios_geral').select('nome_ponto, tipo_ensaio').eq('elemento_estrutural_id', elementoId);
    final categorias = <String, List<String>>{};
    for (final row in (res as List)) {
      final tipo = row['tipo_ensaio']?.toString() ?? 'Ensaio';
      final nome = row['nome_ponto']?.toString() ?? 'Sem nome';
      categorias.putIfAbsent('Pontos de $tipo', () => []).add(nome);
    }
    return categorias;
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
    final arquivoFisico = File(caminhoLocalFoto);

    // Pasta = id do elemento (as políticas do bucket dependem disso); nome,
    // tipo e Content-Type decididos pelo app (ver upload_seguro.dart).
    final nomeArquivo = await _client.storage
        .from('elementos-fotos')
        .enviarArquivoSeguro(elementoId, arquivoFisico);

    return _client.storage.from('elementos-fotos').getPublicUrl(nomeArquivo);
  }

  Future<String> uploadImagemMarcacao({
    required String elementoId,
    required Uint8List bytes,
  }) async {
    final caminhoStorage = '$elementoId/marcacao-planta.png';

    await _client.storage
        .from('elementos-fotos')
        .uploadBinarySemMetadados(
          caminhoStorage,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '0',
            contentType: 'image/png',
            upsert: true,
          ),
        );

    final url = _client.storage
        .from('elementos-fotos')
        .getPublicUrl(caminhoStorage);
    final versao = DateTime.now().millisecondsSinceEpoch;
    return '$url?v=$versao';
  }

  Future<Uint8List> baixarImagemMarcacao(String elementoId) {
    return _client.storage
        .from('elementos-fotos')
        .download('$elementoId/marcacao-planta.png');
  }

  Future<void> removerImagemMarcacao(String elementoId) async {
    await _client.storage.from('elementos-fotos').remove([
      '$elementoId/marcacao-planta.png',
    ]);
  }

  Future<void> removerMarcacao(String elementoId) async {
    try {
      final response = await _client
          .from('elementos_estruturais')
          .update(marcacaoRemovidaPatch)
          .eq('id', elementoId)
          .select('id');

      if (response.isEmpty) {
        throw Exception(
          'Permissão negada (RLS) ou elemento não encontrado no banco de dados.',
        );
      }
    } catch (e) {
      throw Exception('Falha ao remover marcação do elemento: $e');
    }
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

  Future<void> criarTipoElemento(
    String nome,
    String formato,
    String? empresaId,
  ) async {
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
