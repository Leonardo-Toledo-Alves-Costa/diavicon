import '../models/bi_data_point.dart';

/// Várias séries (uma por alias) reduzidas a um número por elemento.
class JuncaoPorElemento {
  /// alias -> elementoId -> valor (média das leituras válidas do elemento).
  final Map<String, Map<String, double>> valores;

  /// elementoId -> um ponto de referência, pra preservar nome/tipo/local.
  final Map<String, BiDataPoint> identidade;

  const JuncaoPorElemento(this.valores, this.identidade);

  Map<String, double?> entradasDe(String elementoId, Iterable<String> aliases) => {
        for (final alias in aliases) alias: valores[alias]?[elementoId],
      };

  /// Junta as séries pela chave de [BiDataPoint]: o elemento estrutural.
  ///
  /// Dentro de um elemento, as leituras de ensaios diferentes não são
  /// pareadas entre si (são feitas em pontos físicos diferentes), então cada
  /// série é reduzida à média do elemento. Leituras nulas, NaN ou infinitas
  /// são ignoradas.
  static JuncaoPorElemento de(Map<String, List<BiDataPoint>> porAlias) {
    final valores = <String, Map<String, double>>{};
    final identidade = <String, BiDataPoint>{};

    for (final entry in porAlias.entries) {
      final somas = <String, double>{};
      final contagens = <String, int>{};
      for (final ponto in entry.value) {
        final valor = ponto.valor;
        if (valor == null || valor.isNaN || valor.isInfinite) continue;
        somas[ponto.elementoId] = (somas[ponto.elementoId] ?? 0) + valor;
        contagens[ponto.elementoId] = (contagens[ponto.elementoId] ?? 0) + 1;
        identidade.putIfAbsent(ponto.elementoId, () => ponto);
      }
      valores[entry.key] = {
        for (final id in somas.keys) id: somas[id]! / contagens[id]!,
      };
    }
    return JuncaoPorElemento(valores, identidade);
  }
}
