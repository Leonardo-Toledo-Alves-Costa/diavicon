import 'dart:math';

import 'package:diavicon/features/ensaios/ensaios_carbonatacao/utils/risco_carbonatacao.dart';
import 'package:diavicon/features/ensaios/ensaios_resistividade/utils/classificacao_resistividade.dart';
import 'package:flutter_test/flutter_test.dart';

String? texto(dynamic classe) => classe?.texto as String?;

void main() {
  group('resistividade: risco de corrosão', () {
    const r = ClassificacaoResistividade.risco;

    test('faixas', () {
      expect(texto(r.classificar(10)), 'Muito Alto');
      expect(texto(r.classificar(18)), 'Alto');
      expect(texto(r.classificar(40)), 'Moderado');
      expect(texto(r.classificar(70)), 'Baixo');
      expect(texto(r.classificar(100)), 'Desprezível');
    });

    test('o valor exatamente no limite cai na classe mais grave (<=)', () {
      expect(texto(r.classificar(15)), 'Muito Alto');
      expect(texto(r.classificar(20)), 'Alto');
      expect(texto(r.classificar(55)), 'Moderado');
      expect(texto(r.classificar(80)), 'Baixo');
    });

    test('leitura zerada ou ausente é "sem medição", não a classe mais grave', () {
      // As cópias antigas do modelo devolviam "Muito Alto" para média 0.
      expect(r.classificar(0), isNull);
      expect(r.classificar(null), isNull);
    });
  });

  group('resistividade: taxa de corrosão', () {
    const t = ClassificacaoResistividade.taxa;

    test('tem quatro classes, sem "Desprezível"', () {
      expect(t.classes.map((c) => c.texto), ['Muito Alto', 'Alto', 'Moderado', 'Baixo']);
    });

    test('20,0 é Moderado e acima é Baixo — o bug do "Desprezível só em 20,0" sumiu', () {
      // Nas cópias antigas: 19,9 → Moderado, 20,0 → Desprezível, 20,1 → Baixo.
      expect(texto(t.classificar(19.9)), 'Moderado');
      expect(texto(t.classificar(20)), 'Moderado');
      expect(texto(t.classificar(20.1)), 'Baixo');
    });
  });

  group('resistividade: permissividade (AASHTO T 358)', () {
    const p = ClassificacaoResistividade.permissividade;

    test('nomes da norma, não deslocados', () {
      // A tela de análise do ponto dizia "Muito Alto" aqui.
      expect(texto(p.classificar(10)), 'Alto');
      expect(texto(p.classificar(15)), 'Moderado');
      expect(texto(p.classificar(30)), 'Baixo');
      expect(texto(p.classificar(100)), 'Muito Baixo');
      expect(texto(p.classificar(300)), 'Desprezível');
    });
  });

  group('cores por gravidade', () {
    test('a classe mais grave é sempre a mesma cor, em qualquer escala', () {
      final graves = ClassificacaoResistividade.todas.map((e) => e.classes.first.corTexto).toSet();
      expect(graves, hasLength(1));
    });

    test('a mais branda também, mesmo em escala de 4 classes', () {
      // Sem a regra das pontas, "Baixo" da taxa (4 classes) sairia amarelo.
      final brandas = ClassificacaoResistividade.todas.map((e) => e.classes.last.corTexto).toSet();
      expect(brandas, hasLength(1));
    });
  });

  group('carbonatação', () {
    AvaliacaoCarbonatacao avaliar({double frente = 10, double cobP = 30, double cobS = 25, int idade = 25}) =>
        RiscoCarbonatacao.avaliar(frenteMedia: frente, cobP: cobP, cobS: cobS, idade: idade);

    test('replica a fórmula do provider: k = frente/√idade, t = (cob/k)²', () {
      final a = avaliar(frente: 10, cobP: 30, cobS: 25, idade: 25);
      expect(a.cobrimentoEfetivo, 25); // o menor dos dois
      expect(a.coefCarb, closeTo(10 / sqrt(25), 1e-12));
      expect(a.tempoCarbonatar, closeTo(pow(25 / 2, 2), 1e-9)); // 156,25
      expect(a.deltaCarb, closeTo(156.25 - 25, 1e-9));
      expect(a.classe!.texto, 'Risco Irrelevante');
    });

    test('faixas pela folga, com limites estritos como na análise', () {
      // Frente = cobrimento → t = idade → Δ = 0 → despassivado.
      expect(avaliar(frente: 25, cobP: 25, cobS: 25, idade: 1).classe!.texto, 'Despassivado');
    });

    test('só um cobrimento informado usa esse', () {
      expect(avaliar(cobP: 0, cobS: 20).cobrimentoEfetivo, 20);
      expect(avaliar(cobP: 20, cobS: 0).cobrimentoEfetivo, 20);
    });

    test('sem frente medida não carbonata: 999 anos, risco irrelevante', () {
      final a = avaliar(frente: 0);
      expect(a.tempoCarbonatar, 999.0);
      expect(a.classe!.texto, 'Risco Irrelevante');
    });

    test('sem cobrimento informado não afirma "Despassivado"', () {
      // A conta daria Δ = −idade. Afirmar despassivação por falta de dado
      // seria grave — aqui vira "sem classificação".
      final a = avaliar(cobP: 0, cobS: 0);
      expect(a.deltaCarb, lessThan(0));
      expect(a.classe, isNull);
    });

    test('idade zero é tratada como 1 ano, igual ao resto do app', () {
      expect(avaliar(idade: 0).coefCarb, avaliar(idade: 1).coefCarb);
    });
  });
}
