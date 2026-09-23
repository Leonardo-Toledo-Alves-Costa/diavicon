import 'dart:math';

import '../../../../core/models/classe_qualitativa.dart';

/// Resultado do cálculo de risco por carbonatação de um elemento.
class AvaliacaoCarbonatacao {
  /// Menor cobrimento informado (normalmente o da armadura secundária).
  final double cobrimentoEfetivo;

  /// Coeficiente de carbonatação k = frente / √idade (mm/√ano).
  final double coefCarb;

  /// Tempo, em anos, até a frente atingir o cobrimento: (cob / k)².
  final double tempoCarbonatar;

  /// Folga até a despassivação: tempo até carbonatar − idade atual.
  final double deltaCarb;

  /// Null quando não há cobrimento informado — ver [RiscoCarbonatacao.avaliar].
  final ClasseQualitativa? classe;

  const AvaliacaoCarbonatacao({
    required this.cobrimentoEfetivo,
    required this.coefCarb,
    required this.tempoCarbonatar,
    required this.deltaCarb,
    required this.classe,
  });
}

/// Risco de corrosão por carbonatação — FONTE ÚNICA da fórmula e das faixas.
///
/// Extraído de analise_carbonatacao_provider, que continua usando isto
/// (com o mesmo resultado de antes). O badge do dashboard usa o mesmo
/// cálculo, por elemento.
class RiscoCarbonatacao {
  /// Faixas pela folga Δ = tempo até carbonatar − idade (anos). Aqui os
  /// limites são estritos (`<`), exatamente como já eram na análise: Δ = 5
  /// é "Moderado", não "Alto".
  ///
  /// Privada de propósito: serve só pra nomes/cores/ordem das classes. O
  /// classificar() dela usa limite inclusivo e descartaria Δ <= 0 como
  /// "sem dado" — a classificação correta é [_classificarDelta].
  static const _escala = EscalaQualitativa(
    nome: 'Risco por carbonatação',
    faixas: [
      (ate: 0, texto: 'Despassivado'),
      (ate: 5, texto: 'Risco Alto'),
      (ate: 15, texto: 'Risco Moderado'),
      (ate: 30, texto: 'Risco Baixo'),
      (ate: null, texto: 'Risco Irrelevante'),
    ],
  );

  static List<ClasseQualitativa> get classes => _escala.classes;

  /// [idade] em anos (já com o mínimo de 1 aplicado por quem chama, como
  /// faz o resto do app: uma estrutura do ano corrente conta como 1 ano).
  static AvaliacaoCarbonatacao avaliar({
    required double frenteMedia,
    required double cobP,
    required double cobS,
    required int idade,
  }) {
    final double cobrimentoEfetivo;
    if (cobS > 0 && cobP > 0) {
      cobrimentoEfetivo = min(cobS, cobP);
    } else if (cobS > 0) {
      cobrimentoEfetivo = cobS;
    } else {
      cobrimentoEfetivo = cobP;
    }

    final idadeSegura = max(1, idade);
    final coefCarb = frenteMedia / sqrt(idadeSegura);
    // Sem frente medida (k = 0) a carbonatação não avança: 999 anos é o
    // "nunca" que o gráfico já usava.
    final tempoCarbonatar = coefCarb > 0 ? pow(cobrimentoEfetivo / coefCarb, 2).toDouble() : 999.0;
    final deltaCarb = tempoCarbonatar - idadeSegura;

    return AvaliacaoCarbonatacao(
      cobrimentoEfetivo: cobrimentoEfetivo,
      coefCarb: coefCarb,
      tempoCarbonatar: tempoCarbonatar,
      deltaCarb: deltaCarb,
      // Sem cobrimento informado a conta dá Δ = −idade e cairia em
      // "Despassivado" — uma afirmação grave feita por falta de dado. Aqui
      // vira "sem classificação"; a tela de análise mantém o comportamento
      // antigo por decisão explícita (ver o provider).
      classe: cobrimentoEfetivo > 0 ? _classificarDelta(deltaCarb) : null,
    );
  }

  static ClasseQualitativa _classificarDelta(double delta) {
    final classes = _escala.classes;
    if (delta <= 0) return classes[0];
    if (delta < 5) return classes[1];
    if (delta < 15) return classes[2];
    if (delta < 30) return classes[3];
    return classes[4];
  }
}
