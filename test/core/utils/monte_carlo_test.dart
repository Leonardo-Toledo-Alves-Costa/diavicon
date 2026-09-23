import 'dart:math';

import 'package:diavicon/core/utils/monte_carlo.dart';
import 'package:diavicon/features/ensaios/ensaios_carbonatacao/utils/curva_despassivacao.dart';
import 'package:flutter_test/flutter_test.dart';

/// Φ(x) da normal padrão (Abramowitz–Stegun 7.1.26), só para os testes.
double _phi(double x) {
  final t = 1 / (1 + 0.3275911 * x.abs() / sqrt2);
  final y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x / 2);
  return x >= 0 ? 0.5 * (1 + y) : 0.5 * (1 - y);
}

void main() {
  group('sorteio', () {
    test('mesma chave, mesma amostra — o dashboard não muda a cada abertura', () {
      final a = MonteCarlo.amostrarNormal(media: 25, desvio: 5, chave: 'cob');
      final b = MonteCarlo.amostrarNormal(media: 25, desvio: 5, chave: 'cob');
      expect(a, b);
    });

    test('chaves diferentes dão amostras independentes, não a mesma sequência', () {
      // Com a mesma semente, duas séries seriam perfeitamente correlacionadas
      // e P(A < B) sairia 0% ou 100%.
      final a = MonteCarlo.amostrarNormal(media: 0, desvio: 1, chave: 'A', naoNegativo: false);
      final b = MonteCarlo.amostrarNormal(media: 0, desvio: 1, chave: 'B', naoNegativo: false);
      expect(a, isNot(b));
      expect(MonteCarlo.probabilidade(a, ComparacaoMC.menor, b), closeTo(0.5, 0.05));
    });

    test('normal sem truncar: o desvio da amostra é o desvio pedido', () {
      // Truncar em [−1, 1] daria ~0,54 aqui.
      final r = MonteCarlo.resumo(MonteCarlo.amostrarNormal(media: 100, desvio: 10, chave: 'x', n: 20000))!;
      expect(r.media, closeTo(100, 0.5));
      expect(r.desvio, closeTo(10, 0.3));
    });

    test('negativos são zerados (grandezas físicas), a pedido', () {
      final v = MonteCarlo.amostrarNormal(media: 1, desvio: 5, chave: 'neg');
      expect(v.every((x) => x >= 0), isTrue);
    });

    test('desvio zero dá amostra constante', () {
      expect(MonteCarlo.amostrarNormal(media: 7, desvio: 0, chave: 'c').toSet(), {7});
    });

    test('1.000 iterações por padrão', () {
      expect(MonteCarlo.amostrarNormal(media: 1, desvio: 1, chave: 'n'), hasLength(1000));
    });
  });

  group('probabilidade', () {
    test('contra valor fixo bate com a normal analítica', () {
      // X ~ N(30, 5): P(X < 25) = Φ(−1) ≈ 15,87%.
      final x = MonteCarlo.amostrarNormal(media: 30, desvio: 5, chave: 'p', n: 50000);
      expect(MonteCarlo.probabilidadeContra(x, ComparacaoMC.menor, 25), closeTo(_phi(-1), 0.01));
    });

    test('amostras inválidas (NaN) ficam fora do total', () {
      expect(MonteCarlo.probabilidade([1, double.nan, 3], ComparacaoMC.maior, [0, 0, 5]), 0.5);
    });

    test('para contínuos, < e ≤ coincidem', () {
      final x = MonteCarlo.amostrarNormal(media: 30, desvio: 5, chave: 'q');
      expect(
        MonteCarlo.probabilidadeContra(x, ComparacaoMC.menor, 25),
        MonteCarlo.probabilidadeContra(x, ComparacaoMC.menorOuIgual, 25),
      );
    });
  });

  group('resumo e histograma', () {
    test('percentis de uma sequência conhecida', () {
      final r = MonteCarlo.resumo([for (var i = 0; i <= 100; i++) i.toDouble()])!;
      expect(r.p5, 5);
      expect(r.p50, 50);
      expect(r.p95, 95);
    });

    test('histograma soma 100%', () {
      final h = MonteCarlo.histograma(MonteCarlo.amostrarNormal(media: 10, desvio: 2, chave: 'h'));
      expect(h.fold<double>(0, (s, c) => s + c.frequencia), closeTo(100, 1e-9));
    });
  });

  group('curva de despassivação', () {
    test('bate com o cálculo analítico do caso de referência (4,32% aos 56,25 anos)', () {
      // Cobrimento ~ N(25, 5) mm; k ~ N(2; 0,4) mm/√ano; t = 56,25 (√t = 7,5).
      // Exato: Φ(−10/√(25+9)) = 4,32%. Com [−1,1] truncado daria 0%.
      final curva = CurvaDespassivacao.calcular(
        kMedia: 2, kDesvio: 0.4, cobMedia: 25, cobDesvio: 5,
        horizonte: 112.5, passos: 2, chave: 'ref', iteracoes: 200000,
      );
      final exato = _phi(-10 / sqrt(34)) * 100;
      expect(curva.tempos[1], 56.25);
      expect(curva.probabilidades[1], closeTo(exato, 0.2));
    });

    test('começa em 0%, é monótona e fecha no horizonte exato', () {
      final c = CurvaDespassivacao.calcular(kMedia: 3, kDesvio: 0.6, cobMedia: 25, cobDesvio: 4, horizonte: 150, chave: 'm');
      expect(c.probabilidades.first, 0);
      expect(c.tempos, hasLength(101));
      expect(c.tempos.last, 150);
      for (var i = 1; i < c.probabilidades.length; i++) {
        expect(c.probabilidades[i], greaterThanOrEqualTo(c.probabilidades[i - 1]));
      }
    });

    test('mesmas entradas e mesma chave: mesma curva (relatório = dashboard)', () {
      CurvaDespassivacao gerar() => CurvaDespassivacao.calcular(
            kMedia: 3, kDesvio: 0.6, cobMedia: 25, cobDesvio: 4, horizonte: 150, chave: CurvaDespassivacao.chaveGeral);
      expect(gerar().probabilidades, gerar().probabilidades);
    });

    test('tempo até X% e "além do horizonte"', () {
      final c = CurvaDespassivacao.calcular(kMedia: 3, kDesvio: 0.6, cobMedia: 25, cobDesvio: 4, horizonte: 150, chave: 't');
      expect(c.tempoAte(20), isNotNull);
      expect(c.tempoAte(20)!, lessThan(c.tempoAte(80)!));
      expect(c.tempoAte(100.1), isNull);
    });

    test('horizonte padrão: 3× abaixo de 10 anos, 2× a partir daí', () {
      expect(CurvaDespassivacao.horizontePadrao(5), 15);
      expect(CurvaDespassivacao.horizontePadrao(40), 80);
    });
  });
}
