import 'dart:math';

import '../../../../core/utils/monte_carlo.dart';

/// Probabilidade de despassivação ao longo do tempo, por Monte Carlo.
///
/// FONTE ÚNICA: o relatório por modelo (três gráficos/tabelas), o gerador de
/// PDF legado e o dashboard usam esta mesma função. Antes eram quatro cópias
/// do mesmo laço, cada uma com sorteio sem semente — cada PDF gerado saía
/// com probabilidades um pouco diferentes.
///
/// Modelo: a frente avança como x(t) = k·√t. Há falha (despassivação) numa
/// iteração quando x(t) > cobrimento. k e cobrimento são sorteados como
/// normais independentes (ver [MonteCarlo]).
class CurvaDespassivacao {
  /// Chave da curva do contexto inteiro. O relatório (gráfico geral) e o
  /// dashboard usam a MESMA chave: com as mesmas entradas, dão exatamente o
  /// mesmo número, não só um número estatisticamente parecido.
  static const chaveGeral = 'carbonatacao|geral';

  /// Tempo em anos de cada ponto da curva.
  final List<double> tempos;

  /// Probabilidade de despassivação (%) em cada tempo.
  final List<double> probabilidades;
  final double horizonte;

  const CurvaDespassivacao._(this.tempos, this.probabilidades, this.horizonte);

  /// Horizonte do gráfico a partir do tempo de referência (idade, se já
  /// despassivado; senão o tempo estimado até despassivar). Regra que os
  /// relatórios já usavam.
  static double horizontePadrao(double tempoReferencia) => tempoReferencia * (tempoReferencia < 10 ? 3 : 2);

  static CurvaDespassivacao calcular({
    required double kMedia,
    required double kDesvio,
    required double cobMedia,
    required double cobDesvio,
    required double horizonte,
    required String chave,
    int passos = 100,
    int iteracoes = MonteCarlo.iteracoes,
  }) {
    final kSim = MonteCarlo.amostrarNormal(media: kMedia, desvio: kDesvio, chave: '$chave|k', n: iteracoes);
    final cobSim = MonteCarlo.amostrarNormal(media: cobMedia, desvio: cobDesvio, chave: '$chave|cob', n: iteracoes);

    final tempos = <double>[];
    final probs = <double>[];
    // Tempo por índice (i·h/passos), não por soma acumulada: somar o passo
    // repetidamente acumula erro de ponto flutuante e às vezes pulava o
    // último ponto do horizonte.
    for (var i = 0; i <= passos; i++) {
      final t = horizonte * i / passos;
      tempos.add(t);
      if (t == 0) {
        probs.add(0);
        continue;
      }
      final raizT = sqrt(t);
      var falhas = 0;
      for (var j = 0; j < iteracoes; j++) {
        if (kSim[j] * raizT > cobSim[j]) falhas++;
      }
      probs.add(falhas / iteracoes * 100);
    }
    return CurvaDespassivacao._(tempos, probs, horizonte);
  }

  /// Primeiro tempo em que a probabilidade alcança [alvo] (%), ou null se
  /// não alcança dentro do horizonte.
  double? tempoAte(double alvo) {
    for (var i = 0; i < probabilidades.length; i++) {
      if (probabilidades[i] >= alvo) return tempos[i];
    }
    return null;
  }

  /// Probabilidade (%) no tempo mais próximo de [t] dentro da curva.
  double probabilidadeEm(double t) {
    if (tempos.isEmpty) return 0;
    var melhor = 0;
    for (var i = 1; i < tempos.length; i++) {
      if ((tempos[i] - t).abs() < (tempos[melhor] - t).abs()) melhor = i;
    }
    return probabilidades[melhor];
  }
}
