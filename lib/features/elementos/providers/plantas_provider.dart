import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planta_model.dart';
import '../repositories/planta_repository.dart';

final plantaRepositoryProvider = Provider<PlantaRepository>((ref) {
  return PlantaRepository(Supabase.instance.client);
});

// Stream que vigia as plantas da estrutura em tempo real
final plantasPorEstruturaProvider = StreamProvider.autoDispose.family<List<PlantaModel>, String>((ref, estruturaId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('estruturas_plantas')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', estruturaId)
      .order('criado_em', ascending: false)
      .map((lista) => lista.map((item) => PlantaModel.fromMap(item)).toList());
});

// Controller para gerenciar o salvamento (loading e actions)
final plantaControllerProvider = StateNotifierProvider<PlantaController, bool>((ref) {
  return PlantaController(ref);
});

class PlantaController extends StateNotifier<bool> {
  final Ref _ref;

  PlantaController(this._ref) : super(false); // false = não está carregando

  Future<void> salvarNovaPlanta({
    required String estruturaId,
    required String titulo,
    required String localVinculado,
    required String caminhoLocal,
    required String extensao,
    required String tamanhoArquivo,
  }) async {
    state = true; // Inicia o loading
    try {
      final repo = _ref.read(plantaRepositoryProvider);

      // 1. Sobe o arquivo pro Storage
      final urlPublica = await repo.uploadArquivoPlanta(
        estruturaId: estruturaId,
        caminhoLocal: caminhoLocal,
        extensao: extensao,
      );

      // 2. Salva no banco de dados
      final novaPlanta = PlantaModel(
        id: '', // Supabase gera
        estruturaId: estruturaId,
        titulo: titulo,
        localVinculado: localVinculado,
        arquivoUrl: urlPublica,
        tamanhoArquivo: tamanhoArquivo,
      );

      await repo.criarPlanta(novaPlanta);
      
      _ref.invalidate(plantasPorEstruturaProvider(estruturaId));
      
    } catch (e) {
      rethrow;
    } finally {
      state = false; // Finaliza o loading
    }
  }
}