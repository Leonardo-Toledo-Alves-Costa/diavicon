import 'package:diavicon/features/dashboards_bi/models/bi_data_point.dart';
import 'package:diavicon/features/dashboards_bi/utils/classificadores_bi.dart';
import 'package:flutter_test/flutter_test.dart';

BiDataPoint p(String el, double? v) =>
    BiDataPoint(elementoId: el, elementoNome: el, tipoElemento: 'Viga', local: 'Subsolo', valor: v);

void main() {
  final whitehurst = buscarClassificadorBi('whitehurst')!;
  final resistividade = buscarClassificadorBi('resistividade')!;
  final carbonatacao = buscarClassificadorBi('carbonatacao')!;

  group('distribuição', () {
    test('conta elementos por classe, da mais grave para a mais branda', () {
      final r = distribuirBadge(whitehurst, {
        'V': [p('e1', 4800), p('e2', 4700), p('e3', 1500), p('e4', 3200)],
      });
      final d = r.dimensoes.single;
      expect(d.contagens.map((c) => '${c.classe.texto}:${c.quantidade}'), ['Ruim:1', 'Bom:1', 'Excelente:2']);
      expect(d.classificados, 4);
      expect(d.unico, isNull);
    });

    test('a viga ruim entre as boas continua visível (não é a média geral)', () {
      final r = distribuirBadge(whitehurst, {
        'V': [for (var i = 0; i < 20; i++) p('boa$i', 4800), p('ruim', 1500)],
      });
      // A média geral daria "Excelente" e esconderia o elemento ruim.
      expect(r.dimensoes.single.contagens.first.classe.texto, 'Ruim');
      expect(r.dimensoes.single.contagens.first.quantidade, 1);
    });

    test('um elemento só vira selo único com o valor', () {
      final r = distribuirBadge(whitehurst, {'V': [p('e1', 4210)]});
      final unico = r.dimensoes.single.unico!;
      expect(unico.classe.texto, 'Ótimo');
      expect(unico.valor, 'V = 4.210 m/s');
    });

    test('várias leituras do mesmo elemento viram a média antes de classificar', () {
      // 3000 e 4000 → média 3500 → "Bom" (Whitehurst: > 3000 e <= 3500).
      final r = distribuirBadge(whitehurst, {'V': [p('e1', 3000), p('e1', 4000)]});
      expect(r.dimensoes.single.unico!.classe.texto, 'Bom');
    });

    test('sem dado nenhum o badge fica vazio', () {
      expect(distribuirBadge(whitehurst, {'V': []}).vazio, isTrue);
    });
  });

  group('resistividade', () {
    test('três dimensões sobre a mesma leitura, usando a fonte única', () {
      final r = distribuirBadge(resistividade, {'rho': [p('e1', 10)]});
      expect(r.dimensoes.map((d) => d.dimensao.nome), ['Risco de corrosão', 'Taxa de corrosão', 'Permissividade iônica']);
      // ρ = 10 está exatamente no limite da faixa "Alto" da taxa (<= 10):
      // pela convenção inclusiva, cai nela, não em "Moderado".
      expect(r.dimensoes.map((d) => d.unico!.classe.texto), ['Muito Alto', 'Alto', 'Alto']);
    });
  });

  group('carbonatação', () {
    test('combina frente, cobrimento e idade por elemento', () {
      // k = 10/√25 = 2 → t = (25/2)² = 156,25 → Δ = 131,25 → Irrelevante.
      final r = distribuirBadge(carbonatacao, {
        'frente': [p('e1', 10)],
        'cobP': [p('e1', 30)],
        'cobS': [p('e1', 25)],
        'idade': [p('e1', 25)],
      });
      final unico = r.dimensoes.single.unico!;
      expect(unico.classe.texto, 'Risco Irrelevante');
      expect(unico.valor, 'Δ = 131,3 anos');
    });

    test('elemento sem cobrimento nenhum não é classificado como despassivado', () {
      final r = distribuirBadge(carbonatacao, {
        'frente': [p('e1', 10)],
        'cobP': [],
        'cobS': [],
        'idade': [p('e1', 25)],
      });
      expect(r.dimensoes.single.classificados, 0);
      expect(r.dimensoes.single.semClassificacao, 1);
    });

    test('um só cobrimento basta', () {
      final r = distribuirBadge(carbonatacao, {
        'frente': [p('e1', 10)],
        'cobP': [],
        'cobS': [p('e1', 25)],
        'idade': [p('e1', 25)],
      });
      expect(r.dimensoes.single.classificados, 1);
    });

    test('sem idade da estrutura o elemento fica sem classificação', () {
      final r = distribuirBadge(carbonatacao, {
        'frente': [p('e1', 10)],
        'cobP': [p('e1', 30)],
        'cobS': [],
        'idade': [p('e1', null)],
      });
      expect(r.dimensoes.single.semClassificacao, 1);
    });
  });
}
