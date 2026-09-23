import '../../../core/utils/monte_carlo.dart';
import 'serie_bi_model.dart';
import '../utils/cores_bi.dart';

enum AnaliseMonteCarloBi {
  distribuicao('Distribuição'),
  probabilidade('Probabilidade de ocorrência'),
  // Só carbonatação por enquanto: é o único ensaio com evolução no tempo
  // (x = k·√t). Cloretos entram aqui depois, com o próprio modelo.
  despassivacao('Probabilidade de despassivação no tempo');

  final String rotulo;
  const AnaliseMonteCarloBi(this.rotulo);

  static AnaliseMonteCarloBi fromChave(String? c) =>
      AnaliseMonteCarloBi.values.firstWhere((a) => a.name == c, orElse: () => AnaliseMonteCarloBi.distribuicao);
}

/// Uma série simulada.
///
/// - **Base**: vem de uma variável ou equação ([valor]). A média e o desvio
///   são os de TODOS os valores do contexto do dashboard; a série é
///   `média + z·σ` sorteada 1.000 vezes.
/// - **Derivada**: uma [expressao] sobre outras séries (pelo [nome]) e
///   números, avaliada amostra a amostra — é assim que a incerteza de V e de
///   R se propaga para o SonReb, em vez de aplicar a fórmula só nas médias.
class SerieMonteCarloBi {
  final String id;

  /// Identificador usado nas expressões (V, R, fc...).
  final String nome;
  final ReferenciaValorBi? valor;
  final String? expressao;
  final int cor;

  const SerieMonteCarloBi({required this.id, required this.nome, this.valor, this.expressao, this.cor = corPadraoBiInt});

  bool get derivada => expressao != null;

  SerieMonteCarloBi copyWith({String? nome, ReferenciaValorBi? valor, String? expressao, int? cor}) => SerieMonteCarloBi(
        id: id,
        nome: nome ?? this.nome,
        valor: valor ?? this.valor,
        expressao: expressao ?? this.expressao,
        cor: cor ?? this.cor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        if (valor != null) 'valor': valor!.toJson(),
        if (expressao != null) 'expressao': expressao,
        'cor': cor,
      };

  factory SerieMonteCarloBi.fromJson(Map<String, dynamic> j) => SerieMonteCarloBi(
        id: j['id'] as String,
        nome: j['nome'] as String? ?? '',
        valor: j['valor'] is Map ? ReferenciaValorBi.fromJson((j['valor'] as Map).cast<String, dynamic>()) : null,
        expressao: j['expressao'] as String?,
        cor: (j['cor'] as num?)?.toInt() ?? corPadraoBiInt,
      );
}

/// Configuração de um card de Monte Carlo.
class ConfigMonteCarloBi {
  final AnaliseMonteCarloBi analise;
  final List<SerieMonteCarloBi> series;

  /// Distribuição: nome da série cujo histograma é exibido.
  final String? serieExibida;

  /// Probabilidade: P([operandoA] [comparacao] [operandoB]). Cada operando é
  /// o nome de uma série ou um número (ex.: "25").
  final String? operandoA;
  final ComparacaoMC comparacao;
  final String? operandoB;

  const ConfigMonteCarloBi({
    this.analise = AnaliseMonteCarloBi.distribuicao,
    this.series = const [],
    this.serieExibida,
    this.operandoA,
    this.comparacao = ComparacaoMC.menor,
    this.operandoB,
  });

  ConfigMonteCarloBi copyWith({
    AnaliseMonteCarloBi? analise,
    List<SerieMonteCarloBi>? series,
    String? serieExibida,
    String? operandoA,
    ComparacaoMC? comparacao,
    String? operandoB,
  }) =>
      ConfigMonteCarloBi(
        analise: analise ?? this.analise,
        series: series ?? this.series,
        serieExibida: serieExibida ?? this.serieExibida,
        operandoA: operandoA ?? this.operandoA,
        comparacao: comparacao ?? this.comparacao,
        operandoB: operandoB ?? this.operandoB,
      );

  Map<String, dynamic> toJson() => {
        'analise': analise.name,
        'series': series.map((s) => s.toJson()).toList(),
        if (serieExibida != null) 'serieExibida': serieExibida,
        if (operandoA != null) 'operandoA': operandoA,
        'comparacao': comparacao.name,
        if (operandoB != null) 'operandoB': operandoB,
      };

  factory ConfigMonteCarloBi.fromJson(Map<String, dynamic> j) => ConfigMonteCarloBi(
        analise: AnaliseMonteCarloBi.fromChave(j['analise'] as String?),
        series: ((j['series'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SerieMonteCarloBi.fromJson(e.cast<String, dynamic>()))
            .toList(),
        serieExibida: j['serieExibida'] as String?,
        operandoA: j['operandoA'] as String?,
        comparacao: ComparacaoMC.fromChave(j['comparacao'] as String?),
        operandoB: j['operandoB'] as String?,
      );
}
