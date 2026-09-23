import 'package:diavicon/features/dashboards_bi/models/bi_data_point.dart';
import 'package:diavicon/features/dashboards_bi/models/variavel_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/utils/variavel_bi_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

BiDataPoint ponto(String elementoId, double? valor, {String nome = ''}) => BiDataPoint(
      elementoId: elementoId,
      elementoNome: nome.isEmpty ? elementoId : nome,
      tipoElemento: 'Viga',
      local: 'Subsolo',
      valor: valor,
    );

/// `fc = V * R` — proposital: a conta é trivial para os testes poderem
/// afirmar o resultado da JUNÇÃO, que é o que está sob teste aqui, e não a
/// aritmética (coberta em variavel_bi_avaliador_test).
final variavel = VariavelBiModel(
  id: 'v1',
  empresaId: 'e1',
  nome: 'Teste',
  expressao: 'V * R',
  entradas: const [
    EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal', estatistica: 'media'),
    EntradaVariavelBi(alias: 'R', fonte: 'esclerometria', campo: 'valor_q', estatistica: 'media'),
  ],
);

void main() {
  test('combina os dois ensaios pelo elemento', () {
    final r = VariavelBiResolver.combinar(variavel, {
      'V': [ponto('el1', 4.0, nome: 'V102'), ponto('el2', 5.0)],
      'R': [ponto('el1', 30.0), ponto('el2', 20.0)],
    });

    expect(r.elementosCalculados, 2);
    expect(r.elementosSemDado, 0);
    expect(r.temLacuna, isFalse);

    final el1 = r.pontos.firstWhere((p) => p.elementoId == 'el1');
    expect(el1.valor, 120.0);
    // A identidade do elemento é preservada para o agrupamento por
    // local/tipo/elemento continuar funcionando no card.
    expect(el1.elementoNome, 'V102');
    expect(el1.local, 'Subsolo');
  });

  test('elemento com só um dos ensaios entra na contagem de lacuna, não no gráfico', () {
    // Caso mais comum em campo: o elemento recebeu esclerometria mas nunca
    // ultrassom.
    final r = VariavelBiResolver.combinar(variavel, {
      'V': [ponto('el1', 4.0)],
      'R': [ponto('el1', 30.0), ponto('el2', 25.0)],
    });

    expect(r.elementosCalculados, 1);
    expect(r.elementosSemDado, 1);
    expect(r.totalElementos, 2);
    expect(r.temLacuna, isTrue);
    expect(r.pontos.map((p) => p.elementoId), ['el1']);
  });

  test('várias leituras no mesmo elemento viram a média antes da fórmula', () {
    // É a decisão metodológica declarada: as 12 leituras de ultrassom e os
    // 16 índices esclerométricos de um elemento não são pareados entre si,
    // então cada ensaio é reduzido a um número por elemento.
    final r = VariavelBiResolver.combinar(variavel, {
      'V': [ponto('el1', 3.0), ponto('el1', 5.0)], // média 4
      'R': [ponto('el1', 20.0), ponto('el1', 40.0)], // média 30
    });

    expect(r.pontos.single.valor, 120.0);
  });

  test('leituras nulas ou infinitas são ignoradas na média', () {
    final r = VariavelBiResolver.combinar(variavel, {
      'V': [ponto('el1', 4.0), ponto('el1', null), ponto('el1', double.infinity)],
      'R': [ponto('el1', 30.0)],
    });

    expect(r.pontos.single.valor, 120.0);
  });

  test('elemento sem nenhum valor válido não vira ponto', () {
    final r = VariavelBiResolver.combinar(variavel, {
      'V': [ponto('el1', null)],
      'R': [ponto('el1', null)],
    });

    expect(r.pontos, isEmpty);
    expect(r.elementosCalculados, 0);
  });

  test('variável sem entradas devolve vazio em vez de explodir', () {
    final semEntradas = VariavelBiModel(
      id: 'v2',
      empresaId: 'e1',
      nome: 'Vazia',
      expressao: '1',
      entradas: const [],
    );
    expect(VariavelBiResolver.combinar(semEntradas, const {}).pontos, isEmpty);
  });

  test('divisão por zero em um elemento não contamina os demais', () {
    final divisao = VariavelBiModel(
      id: 'v3',
      empresaId: 'e1',
      nome: 'Razão',
      expressao: 'V / R',
      entradas: const [
        EntradaVariavelBi(alias: 'V', fonte: 'ultrassom', campo: 'velocidade_longitudinal'),
        EntradaVariavelBi(alias: 'R', fonte: 'esclerometria', campo: 'valor_q'),
      ],
    );

    final r = VariavelBiResolver.combinar(divisao, {
      'V': [ponto('el1', 100.0), ponto('el2', 100.0)],
      'R': [ponto('el1', 0.0), ponto('el2', 4.0)],
    });

    expect(r.elementosCalculados, 1);
    expect(r.elementosSemDado, 1);
    expect(r.pontos.single.elementoId, 'el2');
    expect(r.pontos.single.valor, 25.0);
  });
}
