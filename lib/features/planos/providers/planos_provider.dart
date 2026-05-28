import 'package:diavicon/features/planos/model/planos_model.dart';
import 'package:diavicon/features/planos/repositories/planos_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final planosRepositoryProvider = Provider((ref) => PlanosRepository());


// Provider da lista de planos
final planosListProvider = FutureProvider<List<PlanosModel>>((ref) {
  return ref.watch(planosRepositoryProvider).getPlanos();
});
