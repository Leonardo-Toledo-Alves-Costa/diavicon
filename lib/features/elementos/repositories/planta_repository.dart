import 'package:diavicon/core/security/upload_seguro.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planta_model.dart';

class PlantaRepository {
  final SupabaseClient _client;

  PlantaRepository(this._client);

  // Faz o upload do PDF ou Imagem pro Storage do Supabase
  Future<String> uploadArquivoPlanta({
    required String estruturaId,
    required String caminhoLocal,
    required String extensao,
  }) async {
    // Usa o seu bucket "estruturas" que já existe e é público.
    // O tipo real (foto ou PDF) é lido do conteúdo; [extensao] só vale como
    // informação do seletor e não entra mais no nome (ver upload_seguro.dart).
    final caminhoNoBucket = await _client.storage
        .from('estruturas')
        .enviarArquivoSeguro(
          'plantas',
          File(caminhoLocal),
          prefixo: '${estruturaId}_',
          permitidas: UploadSeguro.extensoesImagemOuPdf,
        );

    return _client.storage
        .from('estruturas')
        .getPublicUrl(caminhoNoBucket);
  }

  // Salva os dados na tabela
  Future<PlantaModel> criarPlanta(PlantaModel planta) async {
    final response = await _client
        .from('estruturas_plantas') 
        .insert(planta.toMap())
        .select()
        .single();

    return PlantaModel.fromMap(response);
  }

  // Busca todas as plantas de uma estrutura
  Future<List<PlantaModel>> buscarPlantasPorEstrutura(String estruturaId) async {
    final response = await _client
        .from('estruturas_plantas')
        .select()
        .eq('estrutura_id', estruturaId)
        .order('criado_em', ascending: false);

    return (response as List).map((item) => PlantaModel.fromMap(item)).toList();
  }
}