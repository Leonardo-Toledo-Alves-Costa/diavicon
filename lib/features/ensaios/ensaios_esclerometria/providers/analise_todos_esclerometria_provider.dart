import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_esclerometria_global_model.dart';

typedef AnaliseEsclerometriaParams = ({String projetoId, String estruturaId});

// Mesmo padrão de `analiseTodosPotencialProvider`.
final analiseTodosEsclerometriaProvider = FutureProvider.family.autoDispose<List<AnaliseEsclerometriaGlobalModel>, AnaliseEsclerometriaParams>(
  (ref, params) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase
          .from('pontos_ensaios_geral')
          .select('''
            id,
            nome_ponto,
            tipo_ensaio,
            elementos_estruturais!inner(nome, tipo, local, estrutura_id),
            ponto_ensaio_esclerometria(inclinacao, indice_k,
              ponto_ensaio_esclerometria_leituras(valor_Q))
          ''')
          .eq('projeto_id', params.projetoId)
          .eq('elementos_estruturais.estrutura_id', params.estruturaId)
          .ilike('tipo_ensaio', '%Esclerometria%');

      if ((response as List).isEmpty) return [];

      return response.map((e) => AnaliseEsclerometriaGlobalModel.fromMap(e)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Erro SQL no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  },
);
