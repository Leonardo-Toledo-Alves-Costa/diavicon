import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/elemento_repository.dart';
import '../models/elemento_model.dart';

// --- REPOSITORY PROVIDER ---
final elementoRepositoryProvider = Provider<ElementoRepository>((ref) {
  return ElementoRepository(Supabase.instance.client);
});

// --- PROVIDER: ELEMENTOS (ATIVOS) DE UMA ESTRUTURA, EM TEMPO REAL ---
// O Supabase vigia a tabela; qualquer INSERT/UPDATE/DELETE dispara o fluxo.
final elementosPorEstruturaProvider = StreamProvider.autoDispose
    .family<List<ElementoModel>, String>((ref, estruturaId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('elementos_estruturais')
      .stream(primaryKey: ['id'])
      .eq('estrutura_id', estruturaId)
      .order('criado_em', ascending: false)
      .map((lista) => lista
          .where((item) => item['ativo'] != false)
          .map((item) => ElementoModel.fromMap(item))
          .toList());
});
