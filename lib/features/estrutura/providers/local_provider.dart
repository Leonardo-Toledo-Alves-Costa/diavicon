import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/local_repository.dart';
import '../models/local_model.dart';

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepository(Supabase.instance.client);
});

// Provider reativo que busca a lista de locais reais da obra
final locaisPorEstruturaProvider = FutureProvider.family<List<LocalModel>, String>((ref, estruturaId) async {
  return ref.read(localRepositoryProvider).buscarLocais(estruturaId);
});