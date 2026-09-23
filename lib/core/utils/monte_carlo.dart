import 'dart:math';

/// Comparação usada nas probabilidades. Sem "igual": para grandezas
/// contínuas P(X = Y) é praticamente zero — "≤"/"≥" é o que se quer dizer.
enum ComparacaoMC {
  menor('<'),
  menorOuIgual('≤'),
  maior('>'),
  maiorOuIgual('≥');

  final String simbolo;
  const ComparacaoMC(this.simbolo);

  bool aplica(double a, double b) => switch (this) {
        ComparacaoMC.menor => a < b,
        ComparacaoMC.menorOuIgual => a <= b,
        ComparacaoMC.maior => a > b,
        ComparacaoMC.maiorOuIgual => a >= b,
      };

  static ComparacaoMC fromChave(String? c) => ComparacaoMC.values.firstWhere((o) => o.name == c, orElse: () => ComparacaoMC.menor);
}

/// Resumo de uma amostra simulada.
class ResumoAmostraMC {
  final int validas;
  final double media;
  final double desvio;
  final double p5;
  final double p50;
  final double p95;

  const ResumoAmostraMC({
    required this.validas,
    required this.media,
    required this.desvio,
    required this.p5,
    required this.p50,
    required this.p95,
  });

  double get coefVariacao => media == 0 ? 0 : desvio / media * 100;
}

/// Motor de Monte Carlo — FONTE ÚNICA do sorteio e das probabilidades,
/// usado pelo dashboard e pelos relatórios de carbonatação.
///
/// Convenções (decididas pela DIAVICON):
///  - distribuição normal SEM truncar: valor = média + z·σ, z ~ N(0,1).
///    Truncar z em [−1, 1] cortaria ~46% do espalhamento e subestimaria a
///    probabilidade de falha — o erro para o lado inseguro;
///  - σ = CV × média. "média + z × CV" literal misturaria unidades;
///  - 1.000 iterações;
///  - semente FIXA por série: o mesmo dashboard (ou o mesmo relatório)
///    mostra o mesmo número toda vez que é aberto. Séries diferentes têm
///    sementes diferentes, senão seriam perfeitamente correlacionadas.
class MonteCarlo {
  static const int iteracoes = 1000;

  /// Semente estável a partir de um texto (FNV-1a, 32 bits). String.hashCode
  /// não serve: não é garantido igual entre execuções/plataformas, e o
  /// objetivo é justamente o resultado se repetir.
  static int semente(String chave) {
    var h = 0x811C9DC5;
    for (final unidade in chave.codeUnits) {
      h ^= unidade;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// N(0,1) por Box-Muller — o mesmo método que o app já usava.
  static double _gaussiana(Random rng) {
    final u1 = 1.0 - rng.nextDouble();
    final u2 = 1.0 - rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  /// Amostra `média + z·σ`, com [chave] definindo a semente.
  ///
  /// [naoNegativo] zera valores negativos, como o app sempre fez: cobrimento,
  /// velocidade, resistividade e frente de carbonatação não existem abaixo
  /// de zero. Com σ = 0 a amostra é constante.
  static List<double> amostrarNormal({
    required double media,
    required double desvio,
    required String chave,
    int n = iteracoes,
    bool naoNegativo = true,
  }) {
    if (desvio <= 0 || desvio.isNaN) return List.filled(n, media);
    final rng = Random(semente(chave));
    return List.generate(n, (_) {
      final v = media + desvio * _gaussiana(rng);
      return naoNegativo && v < 0 ? 0.0 : v;
    });
  }

  /// P(a op b) comparando amostra a amostra (a[i] com b[i]) — as duas séries
  /// são tratadas como independentes. Amostras NaN ficam de fora do total.
  static double probabilidade(List<double> a, ComparacaoMC op, List<double> b) {
    final n = min(a.length, b.length);
    var validas = 0;
    var casos = 0;
    for (var i = 0; i < n; i++) {
      if (a[i].isNaN || b[i].isNaN) continue;
      validas++;
      if (op.aplica(a[i], b[i])) casos++;
    }
    return validas == 0 ? double.nan : casos / validas;
  }

  /// P(a op valor fixo).
  static double probabilidadeContra(List<double> a, ComparacaoMC op, double valor) =>
      probabilidade(a, op, List.filled(a.length, valor));

  static ResumoAmostraMC? resumo(List<double> amostra) {
    final v = amostra.where((x) => !x.isNaN && !x.isInfinite).toList()..sort();
    if (v.isEmpty) return null;
    final media = v.reduce((a, b) => a + b) / v.length;
    final variancia = v.length < 2 ? 0.0 : v.map((x) => pow(x - media, 2)).reduce((a, b) => a + b) / (v.length - 1);
    return ResumoAmostraMC(
      validas: v.length,
      media: media,
      desvio: sqrt(variancia),
      p5: _percentil(v, 0.05),
      p50: _percentil(v, 0.50),
      p95: _percentil(v, 0.95),
    );
  }

  /// Percentil por interpolação linear, sobre lista já ordenada.
  static double _percentil(List<double> ordenada, double q) {
    if (ordenada.length == 1) return ordenada.first;
    final pos = q * (ordenada.length - 1);
    final i = pos.floor();
    final f = pos - i;
    return i + 1 < ordenada.length ? ordenada[i] + f * (ordenada[i + 1] - ordenada[i]) : ordenada[i];
  }

  /// Histograma em [classes] faixas de mesma largura. Devolve o centro de
  /// cada faixa e a frequência relativa (%).
  static List<({double centro, double frequencia})> histograma(List<double> amostra, {int classes = 30}) {
    final v = amostra.where((x) => !x.isNaN && !x.isInfinite).toList();
    if (v.isEmpty) return const [];
    final minimo = v.reduce(min);
    final maximo = v.reduce(max);
    if (maximo == minimo) return [(centro: minimo, frequencia: 100.0)];
    final largura = (maximo - minimo) / classes;
    final contagem = List.filled(classes, 0);
    for (final x in v) {
      final i = ((x - minimo) / largura).floor().clamp(0, classes - 1);
      contagem[i]++;
    }
    return [
      for (var i = 0; i < classes; i++) (centro: minimo + largura * (i + 0.5), frequencia: contagem[i] / v.length * 100),
    ];
  }
}
