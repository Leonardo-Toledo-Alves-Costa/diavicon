import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Completa `tipo_ensaio_id` e `estrutura_id` de um registro de
/// `pontos_ensaios_geral` QUANDO estiverem nulos — nunca sobrescreve.
///
/// Por que existe: pontos criados por versões antigas do app ficaram sem
/// esses dois campos (os repositórios não gravavam a estrutura). O código
/// atual já grava tudo no INSERT e o trigger `set_point_actor_company`
/// recusa ponto novo sem eles, mas as linhas antigas continuavam nulas e
/// sumiam de consultas por estrutura/tipo. Chamado ao salvar qualquer
/// ensaio: reabrir e salvar um ponto antigo o conserta.
///
/// Best-effort: se o RLS não deixar (ponto de outra empresa) ou algo falhar,
/// só registra no log — nunca atrapalha o salvamento do ensaio.
Future<void> completarIdentidadePontoGeral(
  SupabaseClient supabase, {
  required String pontoGeralId,
  String? elementoId,
  String? tipoEnsaioId,
}) async {
  if (pontoGeralId.isEmpty) return;
  try {
    if (tipoEnsaioId != null && tipoEnsaioId.isNotEmpty) {
      await supabase
          .from('pontos_ensaios_geral')
          .update({'tipo_ensaio_id': tipoEnsaioId})
          .eq('id', pontoGeralId)
          .isFilter('tipo_ensaio_id', null);
    }
    if (elementoId != null && elementoId.isNotEmpty) {
      final el = await supabase.from('elementos_estruturais').select('estrutura_id').eq('id', elementoId).maybeSingle();
      final estruturaId = el?['estrutura_id']?.toString();
      if (estruturaId != null && estruturaId.isNotEmpty) {
        await supabase
            .from('pontos_ensaios_geral')
            .update({'estrutura_id': estruturaId})
            .eq('id', pontoGeralId)
            .isFilter('estrutura_id', null);
      }
    }
  } catch (e) {
    debugPrint('[PontoGeral] não foi possível completar estrutura/tipo de $pontoGeralId: $e');
  }
}
