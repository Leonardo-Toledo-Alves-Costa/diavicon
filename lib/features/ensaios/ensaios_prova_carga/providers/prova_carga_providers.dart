import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/prova_carga_repository.dart';

final provaCargaRepositoryProvider = Provider((ref) => ProvaCargaRepository());

typedef ElementosPorLocalArgs = ({String estruturaId, String? local, String? tipoNome});

/// Elementos estruturais de um Local específico, opcionalmente filtrados
/// por Tipo de Elemento — usado nos dropdowns "Elemento Estrutural" da
/// prova de carga (cascata Sistema > Tipo de Elemento > Elemento).
final elementosPorLocalProvaCargaProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, ElementosPorLocalArgs>((ref, args) async {
  if (args.local == null || args.local!.isEmpty) return [];

  var query = Supabase.instance.client
      .from('elementos_estruturais')
      .select('id, nome, tipo')
      .eq('estrutura_id', args.estruturaId)
      .eq('local', args.local!)
      .eq('ativo', true);

  if (args.tipoNome != null && args.tipoNome!.isNotEmpty) {
    query = query.eq('tipo', args.tipoNome!);
  }

  final res = await query.order('nome', ascending: true);
  return List<Map<String, dynamic>>.from(res);
});
