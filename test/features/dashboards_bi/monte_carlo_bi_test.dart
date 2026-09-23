import 'dart:convert';
import 'dart:math';

import 'package:diavicon/core/utils/monte_carlo.dart';
import 'package:diavicon/features/dashboards_bi/models/bi_data_point.dart';
import 'package:diavicon/features/dashboards_bi/models/monte_carlo_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/models/dashboard_card_model.dart';
import 'package:diavicon/features/dashboards_bi/models/serie_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/models/variavel_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/utils/monte_carlo_bi.dart';
import 'package:diavicon/features/dashboards_bi/widgets/editores_series_bi.dart';
import 'package:diavicon/features/ensaios/ensaios_carbonatacao/utils/curva_despassivacao.dart';
import 'package:flutter_test/flutter_test.dart';

BiDataPoint p(String el, double? v) =>
    BiDataPoint(elementoId: el, elementoNome: el, tipoElemento: 'Viga', local: 'Subsolo', valor: v);

List<BiDataPoint> populacao(double media, double desvio, int n, {String el = 'e1'}) {
  // Amostra determinística com a média e o desvio pedidos (±desvio em pares).
  final pontos = <BiDataPoint>[];
  for (var i = 0; i < n; i++) {
    pontos.add(p(el, media + (i.isEven ? desvio : -desvio)));
  }
  return pontos;
}

const _ref = ReferenciaValorBi(fonte: 'x', campo: 'y');

void main() {
  group('séries base', () {
    test('média e desvio vêm da população do contexto', () {
      final cfg = ConfigMonteCarloBi(series: [const SerieMonteCarloBi(id: 's1', nome: 'V', valor: _ref)]);
      final r = simularMonteCarlo(cfg, {'s1': populacao(4000, 200, 20)}, chaveCard: 'c');
      final pop = r.populacoes['V']!;
      expect(pop.media, 4000);
      expect(pop.n, 20);
      final resumo = MonteCarlo.resumo(r.amostras['V']!)!;
      expect(resumo.media, closeTo(4000, 20));
      expect(r.amostras['V'], hasLength(1000));
    });

    test('sem dados vira erro da série, sem derrubar as outras', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 's1', nome: 'V', valor: _ref),
        SerieMonteCarloBi(id: 's2', nome: 'R', valor: _ref),
      ]);
      final r = simularMonteCarlo(cfg, {'s1': populacao(4000, 200, 10), 's2': const []}, chaveCard: 'c');
      expect(r.amostras.containsKey('V'), isTrue);
      expect(r.erros['R'], contains('Sem dados'));
    });

    test('o mesmo card dá o mesmo resultado; cards diferentes não compartilham sorteio', () {
      final cfg = ConfigMonteCarloBi(series: [const SerieMonteCarloBi(id: 's1', nome: 'V', valor: _ref)]);
      final dados = {'s1': populacao(4000, 200, 10)};
      final a = simularMonteCarlo(cfg, dados, chaveCard: 'card1').amostras['V'];
      expect(simularMonteCarlo(cfg, dados, chaveCard: 'card1').amostras['V'], a);
      expect(simularMonteCarlo(cfg, dados, chaveCard: 'card2').amostras['V'], isNot(a));
    });
  });

  group('séries derivadas', () {
    test('expressão avaliada amostra a amostra (propaga a incerteza)', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 'a', nome: 'V', valor: _ref),
        SerieMonteCarloBi(id: 'b', nome: 'R', valor: _ref),
        SerieMonteCarloBi(id: 'c', nome: 'soma', expressao: 'V + R'),
      ]);
      final r = simularMonteCarlo(cfg, {'a': populacao(10, 1, 10), 'b': populacao(5, 1, 10)}, chaveCard: 'k');
      for (var i = 0; i < 1000; i++) {
        expect(r.amostras['soma']![i], closeTo(r.amostras['V']![i] + r.amostras['R']![i], 1e-9));
      }
    });

    test('derivada pode usar outra derivada, em qualquer ordem na lista', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 'd2', nome: 'dobro_soma', expressao: '2 * soma'),
        SerieMonteCarloBi(id: 'd1', nome: 'soma', expressao: 'V + 1'),
        SerieMonteCarloBi(id: 'a', nome: 'V', valor: _ref),
      ]);
      final r = simularMonteCarlo(cfg, {'a': populacao(10, 1, 10)}, chaveCard: 'k');
      expect(r.erros, isEmpty);
      expect(r.amostras['dobro_soma']![0], closeTo(2 * (r.amostras['V']![0] + 1), 1e-9));
    });

    test('referência circular é detectada, não trava', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 'x', nome: 'A', expressao: 'B + 1'),
        SerieMonteCarloBi(id: 'y', nome: 'B', expressao: 'A + 1'),
      ]);
      final r = simularMonteCarlo(cfg, const {}, chaveCard: 'k');
      expect(r.erros.keys, containsAll(['A', 'B']));
    });

    test('derivada de base sem dados herda o erro, com o motivo', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 'a', nome: 'V', valor: _ref),
        SerieMonteCarloBi(id: 'd', nome: 'fc', expressao: 'V * 2'),
      ]);
      final r = simularMonteCarlo(cfg, {'a': const []}, chaveCard: 'k');
      expect(r.erros['fc'], contains('"V"'));
    });

    test('amostra em que a conta não dá número vira NaN e sai das probabilidades', () {
      final cfg = ConfigMonteCarloBi(series: const [
        SerieMonteCarloBi(id: 'a', nome: 'X', valor: _ref),
        SerieMonteCarloBi(id: 'd', nome: 'raiz', expressao: 'sqrt(X - 10)'),
      ]);
      // X ~ N(10, 2): metade das amostras dá raiz de negativo.
      final r = simularMonteCarlo(cfg, {'a': populacao(10, 2, 10)}, chaveCard: 'k');
      final raiz = r.amostras['raiz']!;
      expect(raiz.where((v) => v.isNaN).length, inInclusiveRange(400, 600));
      expect(MonteCarlo.probabilidadeContra(raiz, ComparacaoMC.maiorOuIgual, 0), 1.0);
    });
  });

  group('operandos', () {
    test('número ou nome de série', () {
      final cfg = ConfigMonteCarloBi(series: const [SerieMonteCarloBi(id: 'a', nome: 'V', valor: _ref)]);
      final r = simularMonteCarlo(cfg, {'a': populacao(10, 1, 10)}, chaveCard: 'k');
      expect(operandoMC('25,5', r)!.first, 25.5);
      expect(operandoMC('V', r), same(r.amostras['V']));
      expect(operandoMC('W', r), isNull);
    });
  });

  group('despassivação', () {
    test('mesmas entradas do relatório, mesma curva (paridade PDF = dashboard)', () {
      // Frentes de uma estrutura de 25 anos, cobrimentos P e S por ponto.
      const idade = 25.0;
      final frentes = [8.0, 10.0, 12.0, 9.0, 11.0, 10.5, 9.5];
      final cobP = [32.0, 30.0, 35.0];
      final cobS = [24.0, 26.0, 25.0];

      final r = despassivacaoMC({
        'frente': [for (final f in frentes) p('e1', f)],
        'cobP': [for (final c in cobP) p('e1', c)],
        'cobS': [for (final c in cobS) p('e1', c)],
        'idade': [p('e1', idade)],
      });

      // O cálculo como o relatório faz, à mão.
      double media(List<double> v) => v.reduce((a, b) => a + b) / v.length;
      double desvio(List<double> v) {
        final m = media(v);
        return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / (v.length - 1));
      }

      final ks = frentes.map((f) => f / sqrt(idade)).toList();
      final tempoTotal = pow(media(cobS) / media(ks), 2).toDouble();
      final esperada = CurvaDespassivacao.calcular(
        kMedia: media(ks), kDesvio: desvio(ks),
        cobMedia: media(cobS), cobDesvio: desvio(cobS), // S é o menor
        horizonte: CurvaDespassivacao.horizontePadrao(tempoTotal),
        chave: CurvaDespassivacao.chaveGeral,
      );

      expect(r.erro, isNull);
      expect(r.curva!.tempos, esperada.tempos);
      expect(r.curva!.probabilidades, esperada.probabilidades);
    });

    test('só um cobrimento medido usa esse, em vez de tratar o outro como 0', () {
      final r = despassivacaoMC({
        'frente': [p('e1', 10)],
        'cobP': [p('e1', 30), p('e1', 32)],
        'cobS': const [],
        'idade': [p('e1', 25)],
      });
      expect(r.erro, isNull);
      // Com cobrimento 0, a probabilidade já estaria em 100% na idade atual.
      expect(r.curva!.probabilidadeEm(25), lessThan(100));
    });

    test('sem cobrimento nenhum não inventa curva', () {
      final r = despassivacaoMC({
        'frente': [p('e1', 10)],
        'cobP': const [],
        'cobS': const [],
        'idade': [p('e1', 25)],
      });
      expect(r.curva, isNull);
      expect(r.erro, contains('cobrimento'));
    });

    test('elementos de estruturas com idades diferentes usam a própria idade no k', () {
      final r = despassivacaoMC({
        'frente': [p('velho', 20), p('novo', 5)],
        'cobP': [p('velho', 30), p('novo', 30)],
        'cobS': const [],
        'idade': [p('velho', 100), p('novo', 1)],
      });
      // k = 20/√100 = 2 e 5/√1 = 5 → média 3,5 (e não a média das frentes
      // sobre uma idade só).
      expect(r.erro, isNull);
      expect(r.idadeReferencia, 50.5);
    });
  });


  group('importar equação (SonReb)', () {
    final sonReb = VariavelBiModel(
      id: 'v1',
      empresaId: 'e1',
      nome: 'Resistência estimada SonReb',
      expressao: 'a * pow(V/1000, b) * pow(R, c)',
      entradas: const [
        EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal', estatistica: 'media'),
        EntradaVariavelBi(alias: 'R', fonte: 'esclerometria', campo: 'valor_q', estatistica: 'media'),
      ],
      parametros: const {'a': 0.0286, 'b': 1.246, 'c': 1.85},
    );
    var n = 0;
    String novoId() => 'id${n++}';

    test('cria as bases e a derivada com os coeficientes já no lugar', () {
      final r = importarEquacaoMC(sonReb, const [], novoId: novoId);
      expect(r.series.map((s) => s.nome), ['V', 'R', 'Resistencia_estimada_Son']);
      expect(r.resultado, 'Resistencia_estimada_Son');
      final derivada = r.series.last;
      expect(derivada.expressao, '(0.0286) * pow(V/1000, (1.246)) * pow(R, (1.85))');
      // Base do Monte Carlo usa a população por ponto: sem estatística.
      expect(r.series.first.valor!.estatistica, isNull);
    });

    test('simulada, a derivada é a fórmula aplicada amostra a amostra', () {
      final imp = importarEquacaoMC(sonReb, const [], novoId: novoId);
      final cfg = ConfigMonteCarloBi(series: imp.series);
      final r = simularMonteCarlo(cfg, {
        imp.series[0].id: populacao(4000, 200, 10),
        imp.series[1].id: populacao(35, 3, 10),
      }, chaveCard: 'k');
      final v = r.amostras['V']!, rr = r.amostras['R']!, fc = r.amostras[imp.resultado]!;
      for (var i = 0; i < 1000; i += 97) {
        expect(fc[i], closeTo(0.0286 * pow(v[i] / 1000, 1.246) * pow(rr[i], 1.85), 1e-9));
      }
    });

    test('reaproveita uma série base que já aponta para a mesma variável', () {
      const existente = SerieMonteCarloBi(id: 'x', nome: 'V', valor: ReferenciaValorBi(fonte: 'ultrassom', campo: 'velocidade_longitudinal'));
      final r = importarEquacaoMC(sonReb, const [existente], novoId: novoId);
      expect(r.series.where((s) => s.nome == 'V'), hasLength(1));
    });

    test('nome ocupado por outra variável: cria outro nome e troca na fórmula', () {
      // "V" já existe, mas é resistividade — ligar a fórmula nela seria errado.
      const outra = SerieMonteCarloBi(id: 'x', nome: 'V', valor: ReferenciaValorBi(fonte: 'resistividade', campo: 'resistividade'));
      final r = importarEquacaoMC(sonReb, const [outra], novoId: novoId);
      expect(r.series.map((s) => s.nome), contains('V_2'));
      expect(r.series.last.expressao, contains('pow(V_2/1000'));
      expect(r.series.last.expressao, isNot(contains('pow(V/1000')));
    });
  });

  test('card de Monte Carlo sobrevive a salvar e reabrir', () {
    const card = DashboardCardModel(
      id: 'mc1', tipo: TipoCardBi.monteCarlo, gridX: 0, gridY: 0, largura: 3, altura: 2,
      monteCarlo: ConfigMonteCarloBi(
        analise: AnaliseMonteCarloBi.probabilidade,
        series: [
          SerieMonteCarloBi(id: 's1', nome: 'V', valor: ReferenciaValorBi(fonte: 'ultrassom', campo: 'velocidade_longitudinal')),
          SerieMonteCarloBi(id: 's2', nome: 'fc', expressao: 'V / 100'),
        ],
        operandoA: 'fc',
        comparacao: ComparacaoMC.menorOuIgual,
        operandoB: '25',
      ),
    );
    final json = jsonDecode(jsonEncode(cardsParaSchemaJson([card]))) as Map<String, dynamic>;
    final volta = cardsFromSchemaJson(json).single;
    expect(volta.tipo, TipoCardBi.monteCarlo);
    expect(volta.usaSeries, isTrue);
    final mc = volta.monteCarlo!;
    expect(mc.analise, AnaliseMonteCarloBi.probabilidade);
    expect(mc.series.map((s) => s.nome), ['V', 'fc']);
    expect(mc.series[1].expressao, 'V / 100');
    expect(mc.comparacao, ComparacaoMC.menorOuIgual);
    expect(mc.operandoB, '25');
  });
}
