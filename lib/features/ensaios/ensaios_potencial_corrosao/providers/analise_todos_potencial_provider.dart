import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_potencial_global_model.dart';

typedef AnalisePotencialParams = ({String projetoId, String estruturaId});

final analiseTodosPotencialProvider = FutureProvider.family.autoDispose<List<AnalisePotencialGlobalModel>, AnalisePotencialParams>(
  (ref, params) async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('pontos_ensaios_geral')
          .select('''
            id,
            nome_ponto,
            tipo_ensaio,
            elementos_estruturais!inner (
              nome,
              tipo,
              local,
              estrutura_id,
              estruturas_locais (
                nome
              )
            ),
            ponto_ensaio_potencial (
              ponto_ensaio_potencial_leitura (
                potencial_mv
              )
            )
          ''')
          .eq('projeto_id', params.projetoId)
          .eq('elementos_estruturais.estrutura_id', params.estruturaId)
          .ilike('tipo_ensaio', '%Potencial%'); 

      if ((response as List).isEmpty) return [];

      return response.map((e) => AnalisePotencialGlobalModel.fromMap(e)).toList();

    } on PostgrestException catch (e) {
      throw Exception('Erro SQL no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  },
);