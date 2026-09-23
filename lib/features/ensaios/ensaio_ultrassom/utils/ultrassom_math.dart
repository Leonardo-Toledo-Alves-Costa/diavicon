import 'dart:math';

// Fórmulas do artigo "Desenvolvimento de modelo para determinação da
// resistência à compressão axial do concreto a partir de ensaios não
// destrutivos: ultrassonografia e resistividade elétrica" (ENSUS 2024),
// item 2.3 "Modelos de cálculo" — modelo EQ (equações 1, 2 e 3).
class UltrassomMath {
  static double mean(List<double> valores) {
    if (valores.isEmpty) return 0.0;
    return valores.reduce((a, b) => a + b) / valores.length;
  }

  static double stdDev(List<double> valores) {
    if (valores.length < 2) return 0.0;
    final m = mean(valores);
    final somaQuad = valores.fold<double>(0, (a, v) => a + pow(v - m, 2));
    return sqrt(somaQuad / valores.length);
  }

  static double coefVariacao(List<double> valores) {
    final m = mean(valores);
    if (m == 0) return 0.0;
    return (stdDev(valores) / m) * 100;
  }

  // Equação 1: coeficiente de Poisson dinâmico, a partir das velocidades
  // longitudinal (Vp) e transversal (Vs) — ν = (Vp² - 2Vs²) / (2(Vp² - Vs²)).
  static double poisson({required double vp, required double vs}) {
    final den = 2 * (vp * vp - vs * vs);
    if (den == 0) return 0.0;
    return (vp * vp - 2 * vs * vs) / den;
  }

  // Equação 2: módulo de elasticidade dinâmico — Ed = 2·ρ·Vs²·(1+ν).
  // `densidade` em kg/m³, `vs` em m/s ⇒ Ed em Pa; convertido pra MPa (÷1e6)
  // pra casar com a unidade da equação 3 (NBR 6118, item 8.2.8).
  static double moduloElasticidadeDinamico({
    required double densidade,
    required double vs,
    required double poisson,
  }) {
    return (2 * densidade * vs * vs * (1 + poisson)) / 1e6;
  }

  // Equação 3 (ABNT NBR 6118:2023, item 8.2.8), invertida: dado o módulo de
  // elasticidade (aqui, o Ed dinâmico calculado acima, usado como estimativa
  // de Eci) e o fator de agregado αE, estima-se fck:
  // Eci = αE·5600·√fck  ⇒  fck = (Eci / (αE·5600))².
  static double resistenciaCompressaoEstimada({
    required double ed,
    required double alfaE,
  }) {
    if (alfaE <= 0) return 0.0;
    final base = ed / (alfaE * 5600);
    return base * base;
  }

  // Valor característico (fck) de um conjunto de resultados de resistência:
  // o valor abaixo do qual só 5% das amostras caem (ABNT NBR 12655:2015) —
  // aproximação usual pra distribuição normal: fck = média - 1,645·desvio
  // padrão (z de 95% unicaudal).
  static double valorCaracteristico95(List<double> valores) {
    return mean(valores) - 1.645 * stdDev(valores);
  }

  // Densidade de probabilidade da normal N(média, desvioPadrão) em x — usada
  // pra desenhar a curva de Gauss do gráfico de fck.
  static double normalPdf(double x, double media, double desvioPadrao) {
    if (desvioPadrao <= 0) return 0.0;
    final expoente = -pow(x - media, 2) / (2 * desvioPadrao * desvioPadrao);
    return (1 / (desvioPadrao * sqrt(2 * pi))) * exp(expoente);
  }
}
