import 'package:diavicon/features/ensaios/ensaios_geral/progresso/progresso_ensaios.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _c(String e, String t, int q) => {'estrutura_id': e, 'tipo_ensaio_id': t, 'quantidade': q};
Map<String, dynamic> _p(String e, String t, [Object? r = '12 mm']) => {'estrutura_id': e, 'tipo_ensaio_id': t, 'valor_resultado': r};

void main() {
  test('por tipo: realizados ÷ contratados; "Pendente" não conta', () {
    final p = ProgressoProjeto.calcular(
      contratos: [_c('E1', 'carb', 4)],
      pontos: [_p('E1', 'carb'), _p('E1', 'carb'), _p('E1', 'carb', 'Pendente'), _p('E1', 'carb', null)],
    );
    final t = p.estrutura('E1').tipo('carb');
    expect((t.contratados, t.realizados), (4, 2));
    expect(t.fracao, 0.5);
  });

  test('contratos do mesmo tipo em regiões diferentes somam', () {
    final p = ProgressoProjeto.calcular(contratos: [_c('E1', 'carb', 3), _c('E1', 'carb', 2)], pontos: const []);
    expect(p.estrutura('E1').tipo('carb').contratados, 5);
  });

  test('estrutura: tipos ponderados pelo contratado; excesso não compensa atraso', () {
    final p = ProgressoProjeto.calcular(
      contratos: [_c('E1', 'carb', 10), _c('E1', 'escl', 30)],
      // carbonatação: 15 feitos de 10 (conta 10); esclerometria: 0 de 30.
      pontos: [for (var i = 0; i < 15; i++) _p('E1', 'carb')],
    );
    final e = p.estrutura('E1');
    expect(e.tipo('carb').fracao, 1.0);
    expect(e.tipo('escl').fracao, 0.0);
    expect(e.fracao, 10 / 40);
  });

  test('projeto: média ponderada das estruturas pelos pontos contratados', () {
    final p = ProgressoProjeto.calcular(
      contratos: [_c('E1', 'carb', 10), _c('E2', 'carb', 30)],
      pontos: [
        for (var i = 0; i < 10; i++) _p('E1', 'carb'), // E1 = 100%
        for (var i = 0; i < 3; i++) _p('E2', 'carb'), // E2 = 10%
      ],
    );
    expect(p.estrutura('E1').fracao, 1.0);
    expect(p.estrutura('E2').fracao, 0.1);
    // (1,0×10 + 0,1×30) / 40 = 0,325 — e não a média simples (0,55).
    expect(p.fracao, closeTo(0.325, 1e-9));
  });

  test('sem contrato não há progresso (null), mesmo com pontos avulsos', () {
    final p = ProgressoProjeto.calcular(contratos: const [], pontos: [_p('E1', 'carb')]);
    expect(p.fracao, isNull);
    expect(p.estrutura('E1').fracao, isNull);
    expect(p.estrutura('E1').tipo('carb').realizados, 1);
    expect(ProgressoProjeto.vazio.estrutura('X').fracao, isNull);
  });

  test('estrutura sem contrato não entra na média do projeto', () {
    final p = ProgressoProjeto.calcular(
      contratos: [_c('E1', 'carb', 2)],
      pontos: [_p('E1', 'carb'), _p('E2', 'carb'), _p('E2', 'carb')],
    );
    expect(p.fracao, 0.5);
  });

  test('linhas incompletas são ignoradas', () {
    final p = ProgressoProjeto.calcular(
      contratos: [_c('E1', 'carb', 0), {'estrutura_id': null, 'tipo_ensaio_id': 'carb', 'quantidade': 5}],
      pontos: [{'estrutura_id': 'E1', 'tipo_ensaio_id': null, 'valor_resultado': 'ok'}],
    );
    expect(p.contratados, 0);
    expect(p.fracao, isNull);
  });

  test('texto', () {
    expect(textoProgresso(null), '—');
    expect(textoProgresso(0.999), '99%');
    expect(textoProgresso(1), '100%');
    expect(pontoRealizado(' pendente '), isFalse);
    expect(pontoRealizado('-350 mV'), isTrue);
  });
}
