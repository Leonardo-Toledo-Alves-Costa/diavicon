import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_resistividade_model.dart';

typedef AnaliseParams = ({String projetoId, String estruturaId});

final analiseResistividadeProvider = FutureProvider.family<List<AnaliseResistividadePonto>, AnaliseParams>(
  (ref, params) async {
    try {
      final supabase = Supabase.instance.client; //[cite: 3]
      
      final response = await supabase
          .from('pontos_ensaios_geral') //[cite: 4]
          .select('''
            id,
            nome_ponto,
            tipo_ensaio,
            leituras:ponto_ensaio_resistividade_leitura (
              resistividade,
              hora
            ),
            elementos_estruturais!inner (
              tipo,
              local,
              estrutura_id,
              estruturas_locais (
                nome
              )
            )
          ''') //[cite: 4]
          .eq('projeto_id', params.projetoId)
          .eq('elementos_estruturais.estrutura_id', params.estruturaId)
          .ilike('tipo_ensaio', '%Resistividade%'); 

      if ((response as List).isEmpty) {
        return [];
      }

      return response
          .map((e) => AnaliseResistividadePonto.fromMap(e))
          .toList();

    } on PostgrestException catch (e) {
      throw Exception('Erro SQL no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  },
);