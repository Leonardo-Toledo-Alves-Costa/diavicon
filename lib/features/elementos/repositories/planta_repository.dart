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
    final nomeArquivo = '${estruturaId}_${DateTime.now().millisecondsSinceEpoch}.$extensao';
    final caminhoNoBucket = 'plantas/$nomeArquivo'; 
    
    // 🔥 Usando o seu bucket "estruturas" que já existe e é público!
    await _client.storage
        .from('estruturas')
        .upload(caminhoNoBucket, File(caminhoLocal));

    return _client.storage
        .from('estruturas')
        .getPublicUrl(caminhoNoBucket);
  }

  // Salva os dados na tabela
  Future<PlantaModel> criarPlanta(PlantaModel planta) async {
    final response = await _client
        .from('estruturas_plantas') // 🔥 Tabela nova no Supabase
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