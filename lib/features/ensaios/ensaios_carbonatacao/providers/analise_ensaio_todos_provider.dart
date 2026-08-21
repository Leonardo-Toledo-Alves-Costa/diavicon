import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/analise_ensaio_todos_model.dart';

final analiseEnsaioProvider = FutureProvider.family
    .autoDispose<
      List<AnalisePontoEnsaioModel>,
      ({String projetoId, String estruturaId, String tipoEnsaioNome})
    >((ref, params) async {
      final supabase = Supabase.instance.client;

      try {
        // 1. Busca idade
        final estruturaResp = await supabase
            .from('estruturas')
            .select('ano_concepcao')
            .eq('id', params.estruturaId)
            .maybeSingle();
        int ano = estruturaResp?['ano_concepcao'] ?? DateTime.now().year;
        double idade = (DateTime.now().year - ano).toDouble();
        if (idade < 1) idade = 1.0;

        // 2. Busca pontos e elementosf
        final pontosResp = await supabase
            .from('pontos_ensaios_geral')
            .select('''
          id, nome_ponto,
          elementos_estruturais!inner (tipo, local, estrutura_id)
        ''')
            .eq('projeto_id', params.projetoId)
            .ilike('tipo_ensaio', '%${params.tipoEnsaioNome}%')
            .eq('elementos_estruturais.estrutura_id', params.estruturaId);

        final List<AnalisePontoEnsaioModel> lista = [];

        for (var p in pontosResp as List) {
          final carbResp = await supabase
              .from('ponto_ensaio_carb')
              .select('id, cob_arm_p, cob_arm_s')
              .eq('ponto_ensaio_id', p['id'])
              .maybeSingle();

          List<double> cobrimentosPrin = [];
          List<double> cobrimentosSec = [];
          List<double> frentes = [];

          if (carbResp != null) {
            if (carbResp['cob_arm_p'] != null) {
              cobrimentosPrin.add((carbResp['cob_arm_p'] as num).toDouble());
            }

            if (carbResp['cob_arm_s'] != null) {
              cobrimentosSec.add((carbResp['cob_arm_s'] as num).toDouble());
            }

            final frentesResp = await supabase
                .from('ponto_ensaio_carb_frentes')
                .select('profundidade')
                .eq('ponto_ensaio_id', carbResp['id']);
            frentes = (frentesResp as List)
                .map((f) => (f['profundidade'] as num).toDouble())
                .toList();
          }

          final el = p['elementos_estruturais'];
          lista.add(
            AnalisePontoEnsaioModel(
              id: p['id'],
              nomePonto: p['nome_ponto'] ?? '',
              tipoElemento: el['tipo'] ?? 'Outros',
              local: el['local'] ?? 'Não informado',
              cobrimentosPrin: cobrimentosPrin,
              cobrimentosSec: cobrimentosSec,
              frentes: frentes,
              idade: idade,
            ),
          );
        }
        return lista;
      } catch (e) {
        throw Exception('Erro ao carregar análise: $e');
      }
    });
