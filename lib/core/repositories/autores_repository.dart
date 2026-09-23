import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/autor_exibicao.dart';

/// Resolve os dados de autoria exibíveis de uma lista de registros.
///
/// Sempre em lote: uma tela de elementos ou de pontos de ensaio mostra
/// dezenas de cartões, e um RPC por cartão seria dezenas de round-trips.
class AutoresRepository {
  final SupabaseClient _supabase;
  AutoresRepository(this._supabase);

  /// Mapa `id do autor -> dados exibíveis`. Ids desconhecidos (ou autores que
  /// já não existem mais, já que a FK é ON DELETE SET NULL) simplesmente não
  /// aparecem no mapa — quem chama trata como "sem autoria".
  Future<Map<String, AutorExibicao>> buscarPorIds(Iterable<String?> ids) async {
    final unicos = ids.whereType<String>().where((id) => id.isNotEmpty).toSet().toList();
    if (unicos.isEmpty) return const {};

    try {
      final resposta = await _supabase.rpc('autores_para_exibicao', params: {'p_ids': unicos});
      final linhas = (resposta as List?) ?? const [];
      return {
        for (final linha in linhas)
          if (linha is Map<String, dynamic>)
            AutorExibicao.fromMap(linha).id: AutorExibicao.fromMap(linha),
      };
    } on PostgrestException catch (e) {
      // PGRST202 = a função não existe no banco (a migration
      // 20260917230500_autores_para_exibicao.sql ainda não foi aplicada).
      // Sem isto o selo sumia de todos os cartões — regressão em relação à
      // versão anterior do app, que lia `usuarios` direto.
      if (e.code == 'PGRST202') return _buscarDireto(unicos);
      debugPrint('[Autores] falha ao resolver autoria: ${e.code} ${e.message}');
      return const {};
    } catch (e) {
      // Autoria é enfeite de rastreio: se falhar, a tela some com o badge e
      // segue mostrando o conteúdo.
      debugPrint('[Autores] falha ao resolver autoria: $e');
      return const {};
    }
  }

  /// Plano B sem a RPC: lê `usuarios` + `empresas` direto, como a versão
  /// anterior do app. O RLS de `usuarios` pode devolver só a própria linha —
  /// nesse caso os registros de colegas ficam sem selo (não inventamos uma
  /// empresa). Mesma regra de privacidade da RPC: nome e foto do autor só
  /// para quem é da mesma empresa; de fora, só o logo.
  Future<Map<String, AutorExibicao>> _buscarDireto(List<String> ids) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      final alvo = {...ids, if (uid != null) uid}.toList();
      final resposta = await _supabase
          .from('usuarios')
          .select('id, empresa_id, nome, sobrenome, foto_url, empresas(nome, foto_url)')
          .inFilter('id', alvo);
      final linhas = (resposta as List).whereType<Map<String, dynamic>>().toList();

      String? empresaDoLeitor;
      for (final l in linhas) {
        if (l['id']?.toString() == uid) empresaDoLeitor = l['empresa_id']?.toString();
      }

      final mapa = <String, AutorExibicao>{};
      for (final l in linhas) {
        final id = l['id']?.toString();
        if (id == null || !ids.contains(id)) continue;
        final empresaId = l['empresa_id']?.toString();
        final empresa = l['empresas'] as Map<String, dynamic>?;
        final mesmaEmpresa = empresaId != null && empresaId == empresaDoLeitor;
        final nome = [l['nome'], l['sobrenome']]
            .where((p) => p != null && p.toString().trim().isNotEmpty)
            .join(' ');
        mapa[id] = AutorExibicao.fromMap({
          'autor_id': id,
          'autor_empresa_id': empresaId,
          'empresa_nome': empresa?['nome'],
          'empresa_logo_url': empresa?['foto_url'],
          'autor_nome': mesmaEmpresa ? nome : null,
          'autor_foto_url': mesmaEmpresa ? l['foto_url'] : null,
        });
      }
      return mapa;
    } catch (e) {
      debugPrint('[Autores] falha no plano B (usuarios direto): $e');
      return const {};
    }
  }
}
