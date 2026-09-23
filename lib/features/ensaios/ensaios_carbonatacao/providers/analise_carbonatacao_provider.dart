import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analise_carbonatacao_model.dart';
import '../utils/risco_carbonatacao.dart';

final analiseCarbonatacaoProvider = FutureProvider.family.autoDispose<AnaliseCarbonatacaoModel, String>((ref, pontoGeralId) async {
  final supabase = Supabase.instance.client;

  try {
    // 1. Busca os dados gerais do Ponto
    final pontoResp = await supabase
        .from('pontos_ensaios_geral')
        .select('id, nome_ponto, projeto_id, elemento_estrutural_id, tipo_ensaio_id, criado_por')
        .eq('id', pontoGeralId)
        .single();

    final elementoId = pontoResp['elemento_estrutural_id'] as String?;
    
    // 2. Busca Elemento e Estrutura (Para calcular Idade, Ambiente, CAA)
    Map<String, dynamic>? elementoResp;
    Map<String, dynamic>? estruturaResp;
    if (elementoId != null) {
      elementoResp = await supabase
          .from('elementos_estruturais')
          .select('id, nome, tipo, local, topologia, revestimento, estrutura_id')
          .eq('id', elementoId)
          .maybeSingle();

      if (elementoResp?['estrutura_id'] != null) {
        estruturaResp = await supabase
            .from('estruturas')
            .select('id, nome, conjunto_estrutural_id, utilizacao_id, tipo_id, tipologia_id, ano_concepcao, caa')
            .eq('id', elementoResp!['estrutura_id'])
            .maybeSingle();
      }
    }

    // 3. Busca Dados Específicos de Carbonatação
    final carbResp = await supabase
        .from('ponto_ensaio_carb')
        .select('id, cob_arm_p, bit_arm_p, cob_arm_s, bit_arm_s')
        .eq('ponto_ensaio_id', pontoGeralId)
        .maybeSingle();

    List<double> frentes = [];
    if (carbResp != null) {
      final frentesResp = await supabase
          .from('ponto_ensaio_carb_frentes')
          .select('profundidade')
          .eq('ponto_ensaio_id', carbResp['id']);
      frentes = (frentesResp as List).map((f) => (f['profundidade'] as num).toDouble()).toList();
    }

    // --- CÁLCULOS ESTÁTICOS ---
    int anoAtual = DateTime.now().year;
    int anoConcepcao = (estruturaResp?['ano_concepcao'] as num?)?.toInt() ?? anoAtual;
    int idade = max(1, anoAtual - anoConcepcao); // Evita divisão por zero se idade for 0

    double cobP = (carbResp?['cob_arm_p'] as num?)?.toDouble() ?? 0.0;
    double cobS = (carbResp?['cob_arm_s'] as num?)?.toDouble() ?? 0.0;
    
    // Cobrimento, k, tempo e faixa de risco: fonte unica (RiscoCarbonatacao),
    // a mesma usada pelo badge do dashboard. Resultado identico ao calculo
    // que vivia aqui.
    final avaliacao = RiscoCarbonatacao.avaliar(
      frenteMedia: frentes.isEmpty ? 0 : frentes.reduce((a, b) => a + b) / frentes.length,
      cobP: cobP,
      cobS: cobS,
      idade: idade,
    );
    final cobrimentoEfetivo = avaliacao.cobrimentoEfetivo;
    final coefCarb = avaliacao.coefCarb;
    final tempoCarbonatar = avaliacao.tempoCarbonatar;
    final deltaCarb = avaliacao.deltaCarb;

    double mediaFrentes = frentes.isEmpty ? 0 : frentes.reduce((a, b) => a + b) / frentes.length;
    double maiorFrente = frentes.isEmpty ? 0 : frentes.reduce(max);
    double menorFrente = frentes.isEmpty ? 0 : frentes.reduce(min);

    double variancia = frentes.isEmpty ? 0 : frentes.map((x) => pow(x - mediaFrentes, 2)).reduce((a, b) => a + b) / frentes.length;
    double desvioPadrao = sqrt(variancia);
    double coefVariacao = mediaFrentes == 0 ? 0 : (desvioPadrao / mediaFrentes) * 100;

    // ATENCAO: sem cobrimento informado, RiscoCarbonatacao devolve classe
    // null (nao afirma nada por falta de dado). Esta tela SEMPRE mostrou
    // "Despassivado" nesse caso — mantido de proposito pra nao mudar o
    // comportamento da analise sem decisao explicita.
    final posicao = avaliacao.classe?.posicao ?? 0;
    const condicoes = ['Despassivado', 'Risco Alto', 'Risco Moderado', 'Risco Baixo', 'Risco Irrelevante'];
    // Cores historicas desta tela, por gravidade.
    const coresRisco = [Color(0xFFFF4C4C), Color(0xFFFF8C00), Color(0xFFFFB74D), Color(0xFFAED581), Color(0xFF81C784)];
    final String condicao = condicoes[posicao];
    final Color corRisco = coresRisco[posicao];
    final double tempoCalc = posicao == 0 ? idade.toDouble() : tempoCarbonatar;

    // Fator do gráfico conforme python[cite: 12]
    double fator = tempoCalc < 10 ? 4 : 2;
    double tempoAnalise = tempoCalc * fator;

    return AnaliseCarbonatacaoModel(
      //nomeProjeto: 
      //nomeEstrutura:
      //conjuntoEstrutural:
      //utilizacaoEstrutura:
      //tipoEstrutura:
     // tipologiaEstrutural:
      pontoNome: pontoResp['nome_ponto'] ?? 'Ponto Sem Nome',
      elementoNome: elementoResp?['nome'] ?? '-',
      tipoElemento: elementoResp?['tipo'] ?? '-',
      local: elementoResp?['local'] ?? '-',
      tipoEnsaio: pontoResp['tipo_ensaio']?.toString() ?? 'Frente de carbonatação', // ADICIONADO AQUI
      idadeAnos: idade,
      ambiente: elementoResp?['microclima'] ?? 'Urbano',
      caa: elementoResp?['caa'] ?? estruturaResp?['caa'] ?? '-',
      revestimento: elementoResp?['revestimento'] ?? 'Nenhum',
      cobArmP: cobP,
      bitArmP: (carbResp?['bit_arm_p'] as num?)?.toDouble(),
      cobArmS: cobS,
      bitArmS: (carbResp?['bit_arm_s'] as num?)?.toDouble(),
      carbonatacaoMedia: mediaFrentes,
      carbonatacaoMaior: maiorFrente,
      carbonatacaoMenor: menorFrente,
      coefVariacao: coefVariacao,
      cobrimentoEfetivo: cobrimentoEfetivo,
      coefCarb: coefCarb,
      tempoCarbonatar: tempoCarbonatar,
      deltaCarb: deltaCarb,
      condicaoRisco: condicao,
      corRisco: corRisco,
      tempoCalc: tempoCalc,
      tempoAnaliseGrafico: tempoAnalise,
    );
  } on PostgrestException catch (e) {
    throw Exception('Erro de Banco de Dados: ${e.message}');
  } on AuthException catch (e) {
    throw Exception('Erro de Autenticação: ${e.message}');
  } catch (e) {
    throw Exception('Erro inesperado na análise: $e');
  }
});