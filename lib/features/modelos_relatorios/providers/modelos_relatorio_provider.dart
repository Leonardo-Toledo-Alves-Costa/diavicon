import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/modelo_relatorio_model.dart';
import '../repositories/modelos_relatorio_repository.dart';

final modelosRelatorioRepositoryProvider = Provider<ModelosRelatorioRepository>((ref) {
  return ModelosRelatorioRepository(Supabase.instance.client);
});

final resumoModelosEnsaioProvider =
    FutureProvider.family.autoDispose<List<ResumoModelosEnsaioModel>, String>((ref, empresaId) {
  return ref.watch(modelosRelatorioRepositoryProvider).buscarResumoPorEnsaio(empresaId);
});

class ModelosPorTipoParams {
  final String empresaId;
  final String tipoEnsaioId;
  const ModelosPorTipoParams({required this.empresaId, required this.tipoEnsaioId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelosPorTipoParams && empresaId == other.empresaId && tipoEnsaioId == other.tipoEnsaioId;

  @override
  int get hashCode => empresaId.hashCode ^ tipoEnsaioId.hashCode;
}

final modelosPorTipoEnsaioProvider =
    FutureProvider.family.autoDispose<List<ModeloRelatorioModel>, ModelosPorTipoParams>((ref, params) {
  return ref.watch(modelosRelatorioRepositoryProvider).listarPorTipoEnsaio(params.empresaId, params.tipoEnsaioId);
});

final modeloRelatorioProvider = FutureProvider.family.autoDispose<ModeloRelatorioModel, String>((ref, id) {
  return ref.watch(modelosRelatorioRepositoryProvider).buscarPorId(id);
});
