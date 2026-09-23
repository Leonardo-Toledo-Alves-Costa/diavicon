import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modelo_rdo_model.dart';
import '../repositories/modelos_rdo_repository.dart';

final modelosRdoRepositoryProvider = Provider<ModelosRdoRepository>((ref) {
  return ModelosRdoRepository(ref.watch(supabaseClientProvider));
});

final modelosRdoProvider = FutureProvider.autoDispose.family<List<ModeloRdoModel>, String>((ref, empresaId) {
  return ref.watch(modelosRdoRepositoryProvider).listarModelos(empresaId);
});
