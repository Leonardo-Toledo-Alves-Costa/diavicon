import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ensaio_resumo_model.dart';

class ResumoEnsaiosParams {
  final String projetoId;
  final String estruturaId;
  final String? tipoEnsaioId;

  const ResumoEnsaiosParams({
    required this.projetoId,
    required this.estruturaId,
    this.tipoEnsaioId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResumoEnsaiosParams &&
          runtimeType == other.runtimeType &&
          projetoId == other.projetoId &&
          estruturaId == other.estruturaId &&
          tipoEnsaioId == other.tipoEnsaioId;

  @override
  int get hashCode =>
      projetoId.hashCode ^ estruturaId.hashCode ^ tipoEnsaioId.hashCode;
}

final tiposEnsaioProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('tipos_ensaio')
      .select('id, nome, icone_path')
      .order('nome', ascending: true);

  return (response as List).map((item) {
    return {
      'id': item['id'],
      'nome': item['nome'],
      'icone': item['icone_path'] ?? 'assets/images/ensaios/default.png',
    };
  }).toList();
});

final resumoEnsaiosProvider = FutureProvider.family
    .autoDispose<List<ResumoEnsaioModel>, ResumoEnsaiosParams>((
      ref,
      params,
    ) async {
      final supabase = Supabase.instance.client;

      try {
        // 1. Busca todos os tipos de ensaio disponíveis no sistema
        final tiposResp = await supabase
            .from('tipos_ensaio')
            .select('id, nome, icone_path')
            .order('nome', ascending: true);

        if ((tiposResp as List).isEmpty) return [];

        // 2. Busca os ensaios contratados para esta estrutura específica
        final contratadosResp = await supabase
            .from('ensaios_contratados')
            .select('tipo_ensaio_id, quantidade')
            .eq('estrutura_id', params.estruturaId);

        // 3. Busca todos os pontos executados vinculados a esta estrutura
        var queryExecutados = supabase
            .from('pontos_ensaios_geral')
            .select(
              'tipo_ensaio_id, projeto_id, elementos_estruturais!inner(estrutura_id)',
            )
            .eq('projeto_id', params.projetoId)
            .eq('elementos_estruturais.estrutura_id', params.estruturaId);

        if (params.tipoEnsaioId != null) {
          queryExecutados = queryExecutados.eq(
            'tipo_ensaio_id',
            params.tipoEnsaioId!,
          );
        }
        final executadosResp = await queryExecutados;

        // 4. Mapeia as quantidades contratadas agrupadas por tipo_ensaio_id (UUID)
        Map<String, int> mapContratados = {};
        for (var c in contratadosResp) {
          final tipoId = c['tipo_ensaio_id']?.toString();
          final qtd = (c['quantidade'] as num?)?.toInt() ?? 0;
          if (tipoId != null) {
            mapContratados[tipoId] = (mapContratados[tipoId] ?? 0) + qtd;
          }
        }

        // 5. Mapeia as quantidades realizadas agrupadas DIRETAMENTE pelo tipo_ensaio_id (UUID)
        Map<String, int> mapRealizados = {};
        for (var r in executadosResp) {
          final tipoId = r['tipo_ensaio_id']?.toString();
          if (tipoId != null && tipoId.isNotEmpty) {
            mapRealizados[tipoId] = (mapRealizados[tipoId] ?? 0) + 1;
          }
        }

        // 6. Consolida a lista final fazendo o match pelo ID
        List<ResumoEnsaioModel> lista = [];
        for (var t in (tiposResp as List)) {
          final id = t['id']?.toString() ?? '';

          final contratadas = mapContratados[id] ?? 0;
          final realizadas =
              mapRealizados[id] ?? 0; // Match perfeito usando UUID

          // Só exibe na lista se houver contrato OU se já houver execução
          lista.add(ResumoEnsaioModel.fromJson(t, contratadas, realizadas));
        }

        // 7. Ordena a lista: ensaios contratados aparecem primeiro
        lista.sort((a, b) {
          if (a.contratadas > 0 && b.contratadas == 0) return -1;
          if (a.contratadas == 0 && b.contratadas > 0) return 1;
          return a.nome.compareTo(b.nome);
        });

        return lista;
      } on PostgrestException catch (e) {
        throw Exception('Erro de Banco de Dados: ${e.message}');
      } catch (e) {
        throw Exception('Erro inesperado: $e');
      }
    });

final buscarIdTipoEnsaioProvider = FutureProvider.family<String?, String>((
  ref,
  nomeEnsaio,
) async {
  try {
    final response = await Supabase.instance.client
        .from('tipos_ensaio')
        .select('id')
        .ilike('nome', '%$nomeEnsaio%')
        .maybeSingle();

    return response?['id'] as String?;
  } catch (e) {
    return null;
  }
});
// Provider para buscar os pontos de ensaio atrelados a um elemento específico
final ensaiosDoElementoProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      elementoId,
    ) async {
      try {
        final response = await Supabase.instance.client
            .from('pontos_ensaios_geral')
            .select('''
          id, 
          nome_ponto, 
          valor_resultado, 
          cor_resultado, 
          tipos_ensaio(id, nome, icone_path)
        ''')
            .eq('elemento_estrutural_id', elementoId)
            .order('criado_em', ascending: true);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        throw Exception('Erro ao buscar ensaios do elemento: $e');
      }
    });
