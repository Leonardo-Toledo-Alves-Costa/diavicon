import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioRdoRepository {
  final SupabaseClient _supabase;
  RelatorioRdoRepository(this._supabase);

  static const _tabela = 'relatorio_rdo';

  /// Cria a linha de status ANTES de gerar (status inicial 'Gerando') — o
  /// `RdoModeloReportService.gerar` roda desacoplado da tela (fire-and-forget)
  /// e só faz UPDATE nessa linha ao terminar, nunca insert.
  Future<String> criarRelatorioPendente({
    required String projetoId,
    required String projetoNome,
    required String empresaId,
    required String nomeRelatorio,
    required String modeloId,
    required String formato,
    required String data,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final row = await _supabase.from(_tabela).insert({
        'projeto_id': projetoId,
        'empresa_autora_id': empresaId,
        'criado_por': userId,
        'status': 'Gerando',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'data': data,
          'projeto_nome': projetoNome,
        }),
      }).select('id').single();
      return row['id'].toString();
    } on PostgrestException catch (e) {
      throw Exception('Erro ao iniciar geração do relatório: ${e.message}');
    }
  }

  Future<void> deletar(String id) async {
    try {
      await _supabase.from(_tabela).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Erro ao apagar relatório: ${e.message}');
    }
  }
}
