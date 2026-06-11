import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/estrutura_model.dart';
import 'dart:io';

class EstruturaRepository {
  final SupabaseClient _client;

  EstruturaRepository(this._client);

  /// Cria a estrutura e já regista o projeto a que ela pertence na própria tabela
  Future<EstruturaModel> criarEstrutura(EstruturaModel estrutura, String projetoId) async {
    try {
      final map = estrutura.toJson();
      
      //Insere a estrutura e recebe o objeto criado (com o novo ID gerado)
      final response = await _client.from('estruturas').insert(map).select().single();
      final novaEstrutura = EstruturaModel.fromJson(response);
      
      // Vincula a estrutura recém-criada ao projeto na tabela de ligação
      await vincularEstrutura(novaEstrutura.id, projetoId);
      
      return novaEstrutura;
      
    } catch (e) {
      throw Exception('Falha ao registar estrutura: $e');
    }
  }

  /// Função para vincular a estrutura a um projeto
  Future<void> vincularEstrutura(String estruturaId, String projetoId) async {
    try {
      await _client.from('projeto_estruturas').insert({
        'projeto_id': projetoId,
        'estrutura_id': estruturaId,
      });
    } catch (e) {
      throw Exception('Falha ao vincular estrutura: $e');
    }
  }

  /// Função para desvincular uma estrutura
  Future<void> desvincularEstrutura(String estruturaId, String projetoId) async {
    try {
      await _client.from('projeto_estruturas')
          .delete()
          .match({'projeto_id': projetoId, 'estrutura_id': estruturaId});
    } catch (e) {
      throw Exception('Falha ao desvincular estrutura: $e');
    }
  }

  /// Busca todas as estruturas vinculadas a um projeto específico
  Future<List<EstruturaModel>> buscarEstruturasPorProjeto(
    String projetoId,
  ) async {
    try {
      // Realiza o join através da tabela de relacionamento e traz as tabelas filhas (nomes)
      final response = await _client
          .from('projeto_estruturas')
          .select('''
            estruturas (
              *,
              conjuntos_estruturais(nome),
              utilizacoes_estrutura(nome),
              tipos_estrutura(nome),
              tipologias_estrutura(nome)
            )
          ''')
          .eq('projeto_id', projetoId);

      return (response as List)
          .where((item) => item['estruturas'] != null)
          .map((item) => EstruturaModel.fromJson(item['estruturas']))
          .toList();
    } catch (e) {
      throw Exception('Erro ao carregar lista de estruturas: $e');
    }
  }

  /// FAZ O UPLOAD DA IMAGEM PARA O STORAGE E RETORNA A URL PÚBLICA
  Future<String?> uploadImagemEstrutura(File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'estruturas/$fileName';

      // 1. CHAMA O SUPABASE DIRETAMENTE AQUI
      final supabase = Supabase.instance.client;

      // 2. Faz o upload da imagem
      await supabase.storage.from('projetos').upload(filePath, imageFile);

      // 3. Pega o link público
      final publicUrl = supabase.storage.from('projetos').getPublicUrl(filePath);
      return publicUrl;
      
    } catch (e) {
      throw Exception('Falha ao fazer upload da imagem: $e');
    }
  }
}