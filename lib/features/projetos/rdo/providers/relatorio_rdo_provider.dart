import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/relatorio_rdo_model.dart';
import '../repositories/relatorio_rdo_repository.dart';

final relatorioRdoRepositoryProvider = Provider<RelatorioRdoRepository>((ref) {
  return RelatorioRdoRepository(ref.watch(supabaseClientProvider));
});

/// Relatórios de RDO de uma empresa num projeto — mesmo padrão de
/// `relatoriosInspecaoVisualStreamProvider`: a API de Stream do Supabase só
/// aceita um `.eq()`, então filtra por `projeto_id` no servidor e por
/// `empresa_autora_id` no cliente.
final relatoriosRdoStreamProvider = StreamProvider.autoDispose
    .family<List<RelatorioRdoModel>, ({String projetoId, String empresaId})>((ref, params) {
      final supabase = Supabase.instance.client;
      return supabase
          .from('relatorio_rdo')
          .stream(primaryKey: ['id'])
          .eq('projeto_id', params.projetoId)
          .order('criado_em', ascending: false)
          .map((linhas) => linhas
              .map((e) => RelatorioRdoModel.fromMap(e))
              .where((r) => r.empresaId == params.empresaId)
              .toList());
    });

/// Relatórios de RDO da empresa do usuário em TODOS os projetos — entrada
/// "Relatórios" do drawer de "Meus RDOs". Só um `.eq()`, sem filtro extra
/// no cliente.
final meusRelatoriosRdoStreamProvider = StreamProvider.autoDispose.family<List<RelatorioRdoModel>, String>((ref, empresaId) {
  final supabase = Supabase.instance.client;
  return supabase
      .from('relatorio_rdo')
      .stream(primaryKey: ['id'])
      .eq('empresa_autora_id', empresaId)
      .order('criado_em', ascending: false)
      .map((linhas) => linhas.map((e) => RelatorioRdoModel.fromMap(e)).toList());
});
