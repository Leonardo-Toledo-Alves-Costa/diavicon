import 'dart:math';

class CarbonatacaoMath {
  // Média de uma lista
  static double mean(List<double> data) {
    if (data.isEmpty) return 0.0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  // Desvio Padrão amostral
  static double stdDev(List<double> data) {
    if (data.length < 2) return 0.0;
    final m = mean(data);
    final variance = data.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / (data.length - 1);
    return sqrt(variance);
  }

  // O sorteio (Box-Muller) mudou para core/utils/monte_carlo.dart, com
  // semente fixa — o daqui não tinha semente, e cada relatório gerado saía
  // com probabilidades diferentes.
}