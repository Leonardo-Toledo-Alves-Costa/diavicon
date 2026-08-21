import 'package:diavicon/features/ensaios/ensaios_geral/models/ensaio_resumo_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final itensContratadosProvider = FutureProvider.family
    .autoDispose<List<ResumoEnsaioModel>, String>(
  (ref, estruturaId) async {
    final supabase = Supabase.instance.client;

    final tiposResp = await supabase
        .from('tipos_ensaio')
        .select('id, nome, icone_path')
        .order('nome', ascending: true);

    final contratadosResp = await supabase
        .from('ensaios_contratados')
        .select('tipo_ensaio_id, quantidade')
        .eq('estrutura_id', estruturaId);

    final Map<String, int> mapContratados = {};

    for (final c in contratadosResp) {
      final tipoId = c['tipo_ensaio_id']?.toString();
      final quantidade = (c['quantidade'] as num?)?.toInt() ?? 0;

      if (tipoId != null) {
        mapContratados[tipoId] =
            (mapContratados[tipoId] ?? 0) + quantidade;
      }
    }

    return (tiposResp as List).map((t) {
      final tipoId = t['id'].toString();

      return ResumoEnsaioModel.fromJson(
        t,
        mapContratados[tipoId] ?? 0,
        0,
      );
    }).where((item) => item.contratadas > 0).toList();
  },
);