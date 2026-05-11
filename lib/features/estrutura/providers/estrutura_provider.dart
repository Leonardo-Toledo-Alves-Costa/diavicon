import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/estrutura_repository.dart';
import '../models/estrutura_model.dart';

final estruturaRepositoryProvider = Provider<EstruturaRepository>((ref) {
  return EstruturaRepository(Supabase.instance.client);
});


final projetoEstruturasProvider = StreamProvider.family<List<EstruturaModel>, String>((ref, projetoId) {
  final supabase = Supabase.instance.client;
  final repo = ref.watch(estruturaRepositoryProvider);

  // O Supabase vigia a tabela de ligação. Sempre que houver INSERT ou DELETE nela,
  // esse fluxo dispara e nós chamamos o repo.buscarEstruturasPorProjeto()
  return supabase
      .from('projeto_estruturas')
      .stream(primaryKey: ['projeto_id', 'estrutura_id'])
      .eq('projeto_id', projetoId)
      .asyncMap((event) => repo.buscarEstruturasPorProjeto(projetoId));
});