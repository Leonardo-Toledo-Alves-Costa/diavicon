import 'dart:math' as math;

import 'package:diavicon/features/dashboards_bi/models/variavel_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/utils/variavel_bi_avaliador.dart';
import 'package:flutter_test/flutter_test.dart';

/// SonReb: estima a resistência à compressão combinando a velocidade
/// ultrassônica longitudinal (V) e o índice esclerométrico (R), ambos
/// agregados por elemento.
VariavelBiModel sonReb({
  String expressao = 'a * pow(V, b) * pow(R, c)',
  Map<String, double> parametros = const {'a': 0.0286, 'b': 1.246, 'c': 1.85},
  List<EntradaVariavelBi>? entradas,
  double? valorMin,
  double? valorMax,
  String nome = 'Resistência estimada SonReb',
}) =>
    VariavelBiModel(
      id: 'v1',
      empresaId: 'e1',
      nome: nome,
      unidade: 'MPa',
      expressao: expressao,
      valorMin: valorMin,
      valorMax: valorMax,
      entradas: entradas ??
          const [
            EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal', estatistica: 'media'),
            EntradaVariavelBi(alias: 'R', fonte: 'esclerometria', campo: 'valor_q', estatistica: 'media'),
          ],
      parametros: parametros,
    );

void main() {
  group('validação estática (bloqueia o salvamento)', () {
    test('a fórmula do SonReb passa', () {
      expect(VariavelBiAvaliador.validar(sonReb()).ok, isTrue);
    });

    test('alias usado na fórmula mas não cadastrado é recusado', () {
      final v = sonReb(
        entradas: const [
          EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal'),
        ],
      );
      final r = VariavelBiAvaliador.validar(v);
      expect(r.ok, isFalse);
      expect(r.erros.join(), contains('não existe'));
    });

    test('função desconhecida é recusada', () {
      final r = VariavelBiAvaliador.validar(sonReb(expressao: 'raizQuadrada(V) * R'));
      expect(r.ok, isFalse);
      expect(r.erros.join(), contains('raizQuadrada'));
    });

    test('sintaxe quebrada é recusada com mensagem legível', () {
      final r = VariavelBiAvaliador.validar(sonReb(expressao: 'a * (V + '));
      expect(r.ok, isFalse);
      expect(r.erros.join(), contains('não pôde ser interpretada'));
    });

    test('alias duplicado é recusado', () {
      final v = sonReb(
        entradas: const [
          EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal'),
          EntradaVariavelBi(alias: 'V', fonte: 'esclerometria', campo: 'valor_q'),
        ],
      );
      expect(VariavelBiAvaliador.validar(v).erros.join(), contains('mais de uma'));
    });

    test('alias colidindo com parâmetro é recusado', () {
      // 'a' como alias de entrada E como coeficiente: a expressão ficaria
      // ambígua e o resultado dependeria da ordem de inserção no contexto.
      final v = sonReb(
        expressao: 'a * V',
        entradas: const [EntradaVariavelBi(alias: 'a', fonte: 'ultrassom', campo: 'velocidade_longitudinal')],
        parametros: const {'a': 2},
      );
      expect(VariavelBiAvaliador.validar(v).erros.join(), contains('ao mesmo tempo'));
    });

    test('alias que não é identificador válido é recusado', () {
      final v = sonReb(
        expressao: 'V',
        entradas: const [EntradaVariavelBi(alias: 'vel. long', fonte: 'ultrassom', campo: 'velocidade_longitudinal')],
        parametros: const {},
      );
      expect(VariavelBiAvaliador.validar(v).ok, isFalse);
    });

    test('faixa esperada invertida é recusada', () {
      final r = VariavelBiAvaliador.validar(sonReb(valorMin: 150, valorMax: 5));
      expect(r.erros.join(), contains('invertida'));
    });

    test('variável sem nome é recusada', () {
      expect(VariavelBiAvaliador.validar(sonReb(nome: '  ')).ok, isFalse);
    });
  });

  group('avaliação (nunca derruba o card)', () {
    test('calcula o SonReb com V e R do elemento', () {
      // V em km/s: é a unidade que estes coeficientes publicados esperam.
      final valor = VariavelBiAvaliador.avaliar(sonReb(), {'V': 4.0, 'R': 30.0});
      final esperado = 0.0286 * math.pow(4.0, 1.246) * math.pow(30.0, 1.85);
      // Compara com a conta feita direto em Dart: o que está sob teste é o
      // parser e o preenchimento do contexto (entradas + parâmetros +
      // funções), não a aritmética do dart:math.
      expect(valor, isNotNull);
      expect(valor!, closeTo(esperado, esperado * 1e-9));
    });

    test('elemento sem um dos ensaios devolve null, não exceção', () {
      // Caso real: o elemento tem esclerometria mas nunca recebeu ultrassom.
      expect(VariavelBiAvaliador.avaliar(sonReb(), {'R': 38.0}), isNull);
      expect(VariavelBiAvaliador.avaliar(sonReb(), {'V': 4200.0, 'R': null}), isNull);
    });

    test('divisão por zero devolve null em vez de Infinito', () {
      final v = sonReb(expressao: 'V / R', parametros: const {});
      expect(VariavelBiAvaliador.avaliar(v, {'V': 4200.0, 'R': 0.0}), isNull);
    });

    test('raiz de negativo devolve null em vez de NaN', () {
      final v = sonReb(expressao: 'sqrt(V - R)', parametros: const {});
      expect(VariavelBiAvaliador.avaliar(v, {'V': 10.0, 'R': 99.0}), isNull);
    });

    test('os parâmetros são o que se recalibra, sem mexer na expressão', () {
      final original = VariavelBiAvaliador.avaliar(sonReb(), {'V': 4200.0, 'R': 38.0})!;
      final recalibrada = VariavelBiAvaliador.avaliar(
        sonReb(parametros: const {'a': 0.0572, 'b': 1.246, 'c': 1.85}),
        {'V': 4200.0, 'R': 38.0},
      )!;
      expect(recalibrada, closeTo(original * 2, original * 0.01));
    });
  });

  group('faixa plausível', () {
    test('sinaliza o erro de unidade que passa por todas as outras checagens', () {
      // Estes coeficientes esperam V em km/s. Informar V em m/s (4000 em vez
      // de 4,0) não produz erro nenhum: a expressão é válida, roda, e devolve
      // um número quatro ordens de grandeza acima do possível. Nenhuma
      // validação de sintaxe pega isso — só a faixa plausível.
      final v = sonReb(valorMin: 5, valorMax: 150);

      final unidadeCerta = VariavelBiAvaliador.avaliar(v, {'V': 4.0, 'R': 30.0})!;
      expect(VariavelBiAvaliador.foraDaFaixa(v, unidadeCerta), isFalse);

      final unidadeErrada = VariavelBiAvaliador.avaliar(v, {'V': 4000.0, 'R': 30.0})!;
      expect(unidadeErrada, greaterThan(unidadeCerta * 1000));
      expect(VariavelBiAvaliador.foraDaFaixa(v, unidadeErrada), isTrue);
    });

    test('sem faixa declarada nada é sinalizado', () {
      expect(VariavelBiAvaliador.foraDaFaixa(sonReb(), 999999), isFalse);
    });
  });

  group('classificação da variável', () {
    test('duas fontes = multi-ensaio', () {
      expect(sonReb().ehMultiEnsaio, isTrue);
      expect(sonReb().fontesNecessarias, {'ultrassom', 'esclerometria'});
    });

    test('uma fonte só = métrica calculada, mesma entidade', () {
      final v = sonReb(
        expressao: 'V / 1000',
        entradas: const [EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal')],
        parametros: const {},
      );
      expect(v.ehMultiEnsaio, isFalse);
      expect(VariavelBiAvaliador.validar(v).ok, isTrue);
    });
  });
}
