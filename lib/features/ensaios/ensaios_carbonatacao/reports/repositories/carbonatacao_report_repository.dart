// ensaios_carbonatacao/reports/carbonatacao_report_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final carbonatacaoReportRepoProvider = Provider((ref) => CarbonatacaoReportRepository(Supabase.instance.client));

class CarbonatacaoReportRepository {
  final SupabaseClient _supabase;
  CarbonatacaoReportRepository(this._supabase);

  Future<Map<String, dynamic>> buscarDadosRelatorio(String projetoId, String estruturaId) async {
    try {
      // 1. Busca Nomes do Projeto e Estrutura
      final proj = await _supabase.from('projetos').select('nome').eq('id', projetoId).maybeSingle();
      final est = await _supabase.from('estruturas').select('nome, caa, ano_concepcao, conjunto_estrutural_id, utilizacao_id, tipo_id, tipologia_id').eq('id', estruturaId).maybeSingle();
     
      // 2. Busca todos os pontos de carbonatação atrelados a essa estrutura
      // Trazendo dados da tabela filha e da tabela geral através do JOIN
      final pontos = await _supabase
          .from('ponto_ensaio_carb')
          .select('''
            *,
            ponto_ensaio_carb_frentes ( profundidade ),
            galeria_ponto_ensaio_carb ( imagem_url, referencia ),
            pontos_ensaios_geral!inner ( valor_resultado, cor_resultado ),
            elementos_estruturais!inner ( estrutura_id, nome, tipo, local, revestimento )
          ''')
          .eq('projeto_id', projetoId)
          .eq('elementos_estruturais.estrutura_id', estruturaId);

      
      return {
        'projeto': proj?['nome'] ?? 'Não informado',
        'estrutura': est?['nome'] ?? 'Não informado',
        'caa': est?['caa'] ?? '-',
        //'exposicao': est?['condicao_exposicao'] ?? '-',
        'pontos': pontos,
      };
    
     
    
    } on PostgrestException catch (e) {
      throw Exception('Erro ao buscar dados do relatório: ${e.message}');
    }
  }
}