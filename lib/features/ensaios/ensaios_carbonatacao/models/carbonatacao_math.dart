import 'dart:math';

class CarbonatacaoMath {
  static final Random _random = Random();

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

  // Box-Muller Transform para gerar curva normal N(0,1)
  static double _nextGaussian() {
    double u1 = 1.0 - _random.nextDouble(); 
    double u2 = 1.0 - _random.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  // Gera array com distribuição normal
  static List<double> randomNormal(double mean, double stdDev, int count) {
    if (stdDev <= 0) return List.filled(count, mean);
    return List.generate(count, (_) {
      double val = mean + stdDev * _nextGaussian();
      return val < 0 ? 0.0 : val; // Evita valores negativos
    });
  }
}