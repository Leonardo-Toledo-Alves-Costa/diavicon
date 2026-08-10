import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/local_repository.dart';
import '../models/local_model.dart';

// 🔥 Import necessário para pegar o ID da empresa logada
import '../../auth/providers/auth_provider.dart'; 

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepository(Supabase.instance.client);
});

final locaisPorEstruturaProvider = FutureProvider.family<List<LocalModel>, String>((ref, estruturaId) async {
  return ref.read(localRepositoryProvider).buscarLocais(estruturaId);
});

// 🔥 PROVIDERS PARA OS DROPDOWNS EM TEMPO REAL
final tipologiasLocalProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final supabase = Supabase.instance.client;
  final user = ref.watch(currentUserProvider);
  final empresaId = user?.empresaId;
  
  if (empresaId == null) return Stream.value([]);

  return supabase
      .from('tipologias_local')
      .stream(primaryKey: ['id'])
      .eq('empresa_id', empresaId)
      .order('nome', ascending: true)
      .map((lista) => lista.map((e) => e['nome'] as String).toList());
});

final condicoesLocalProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final supabase = Supabase.instance.client;
  final user = ref.watch(currentUserProvider);
  final empresaId = user?.empresaId;
  
  if (empresaId == null) return Stream.value([]);

  return supabase
      .from('condicoes_local')
      .stream(primaryKey: ['id'])
      .eq('empresa_id', empresaId)
      .order('nome', ascending: true)
      .map((lista) => lista.map((e) => e['nome'] as String).toList());
});