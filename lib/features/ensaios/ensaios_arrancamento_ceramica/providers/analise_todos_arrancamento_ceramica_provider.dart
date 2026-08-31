import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_arrancamento_ceramica_model.dart'; 

typedef AnaliseArrancamentoCeramicaParams = ({String projetoId, String estruturaId});

final analiseArrancamentoCeramicaProvider = FutureProvider.family.autoDispose<List<PontoArrancamentoCeramicaGlobal>, AnaliseArrancamentoCeramicaParams>(
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
            ponto_ensaio_arrancamento (
              id,
              ponto_ensaio_arrancamento_leitura (
                carga,
                area,
                ponto_ensaio_arrancamento_ruptura (
                  tipo_ruptura,
                  porcentagem
                )
              )
            )
          ''')
          .eq('projeto_id', params.projetoId)
          .eq('elementos_estruturais.estrutura_id', params.estruturaId)
          .ilike('tipo_ensaio', '%Placa Cerâmica%'); // Filtro Específico

      if ((response as List).isEmpty) {
        return [];
      }

      return response.map((e) => PontoArrancamentoCeramicaGlobal.fromMap(e)).toList();

    } on PostgrestException catch (e) {
      throw Exception('Erro SQL no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro inesperado: $e');
    }
  },
);