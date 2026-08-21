import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ensaio_resumo_model.dart';

class EnsaiosRepository {
  final SupabaseClient _supabase;
  EnsaiosRepository(this._supabase);

  Future<List<ResumoEnsaioModel>> getResumoEnsaiosEstrutura({
    required String projetoId,
    required String estruturaId,
  }) async {
    try {
      // 1. Busca os tipos de ensaio disponíveis
      final tiposResp = await _supabase
          .from('tipos_ensaio')
          .select('id, nome, icone_path')
          .order('nome', ascending: true);

      if (tiposResp.isEmpty) return [];

      // 2. Busca ensaios contratados para a estrutura[cite: 2]
      final contratadosResp = await _supabase
          .from('ensaios_contratados')
          .select('tipo_ensaio_id, quantidade')
          .eq('estrutura_id', estruturaId);

      // 3. Busca pontos já realizados de forma segura[cite: 2]
      final realizadosValidadosResp = await _supabase
          .from('pontos_ensaios_geral')
          .select('tipo_ensaio_id, estrutura_id')
          .eq('projeto_id', projetoId)
          .eq('estrutura_id', estruturaId);

      // 4. Mapeia quantidades contratadas com segurança de tipo
      Map<String, int> mapContratados = {};
      for (var c in (contratadosResp as List)) {
        final tipoEnsaioId = c['tipo_ensaio_id']?.toString();
        if (tipoEnsaioId != null) {
          final qtd = (c['quantidade'] as num?)?.toInt() ?? 0;
          mapContratados[tipoEnsaioId] = (mapContratados[tipoEnsaioId] ?? 0) + qtd;
        }
      }

      // 5. Mapeia quantidades realizadas
      Map<String, int> mapRealizados = {};
      if (realizadosValidadosResp is List) {
        for (var r in realizadosValidadosResp) {
          final tipoEnsaioId = (r['tipo_ensaio_id'] ?? '').toString().trim().toLowerCase();
          if (tipoEnsaioId.isNotEmpty) {
            mapRealizados[tipoEnsaioId] = (mapRealizados[tipoEnsaioId] ?? 0) + 1;
          }
        }
      }

      // 6. Constrói a lista consolidada
      List<ResumoEnsaioModel> lista = [];
      for (var t in tiposResp) {
        final id = t['id']?.toString() ?? '';
        final nome = t['nome']?.toString() ?? 'Ensaio sem nome';
        final iconePath = t['icone_path']?.toString();

        final contratadas = mapContratados[id] ?? 0;

        final nomeLower = nome.trim().toLowerCase();
        int realizadas = mapRealizados[nomeLower] ?? 0;

        // Normalização específica para carbonatação conforme tabelas criadas[cite: 2]
        if (nomeLower.contains('carbonata')) {
          realizadas = mapRealizados['frente de carbonatação'] ??
              mapRealizados['carbonatação'] ?? realizadas;
        }

        lista.add(ResumoEnsaioModel(
          id: id,
          nome: nome,
          iconePath: (iconePath != null && iconePath.isNotEmpty) ? iconePath : 'assets/images/ensaios/default.png',
          contratadas: contratadas,
          realizadas: realizadas,
        ));
      }

      // 7. Ordenação limpa
      lista.sort((a, b) {
        if (a.contratadas > 0 && b.contratadas == 0) return -1;
        if (a.contratadas == 0 && b.contratadas > 0) return 1;
        return a.nome.compareTo(b.nome);
      });

      return lista;

    } on PostgrestException catch (e) {
      throw Exception('Erro de Banco de Dados (${e.code}): ${e.message}');
    } on AuthException catch (e) {
      throw Exception('Erro de Autenticação: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado no repositório: $e');
    }
  }
}