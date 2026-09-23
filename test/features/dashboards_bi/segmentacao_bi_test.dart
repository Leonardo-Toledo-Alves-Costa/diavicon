import 'package:diavicon/features/dashboards_bi/models/bi_data_point.dart';
import 'package:diavicon/features/dashboards_bi/models/campos_bi_catalogo.dart';
import 'package:diavicon/features/dashboards_bi/utils/segmentacao_bi.dart';
import 'package:flutter_test/flutter_test.dart';

BiDataPoint p(double v, {String el = 'e1', String local = 'Subsolo', String tipo = 'Viga', String? categoria}) =>
    BiDataPoint(elementoId: el, elementoNome: el, tipoElemento: tipo, local: local, valor: v, categoria: categoria);

void main() {
  group('segmentar pelo valor', () {
    test('GUT por local, empilhado por tipo de elemento: os pedaços somam o total', () {
      final b = segmentarSerieBi(
        pontos: [p(10, tipo: 'Viga'), p(5, tipo: 'Viga'), p(7, tipo: 'Pilar'), p(3, tipo: 'Pilar', local: 'Cobertura')],
        agruparPor: 'local',
        segmentarPor: 'tipoElemento',
        agregacao: AgregacaoBi.soma,
      );
      expect(b.segmentos, ['Pilar', 'Viga']);
      expect(b.valores['Viga'], {'Subsolo': 15});
      expect(b.valores['Pilar'], {'Subsolo': 7, 'Cobertura': 3});
      expect(b.unidade, isNull);
    });

    test('por categoria usa a categoria do ponto (ex.: categoria da anomalia)', () {
      final b = segmentarSerieBi(
        pontos: [p(10, categoria: 'Fissura'), p(4, categoria: 'Corrosão'), p(6, categoria: 'Fissura'), p(1)],
        agruparPor: 'local',
        segmentarPor: 'categoria',
        agregacao: AgregacaoBi.soma,
      );
      expect(b.valores['Fissura'], {'Subsolo': 16});
      expect(b.valores['Corrosão'], {'Subsolo': 4});
      expect(b.valores['Sem categoria'], {'Subsolo': 1});
    });
  });

  group('segmentar por classificação', () {
    final whitehurst = escalasSegmentacaoBi.firstWhere((e) => e.id.startsWith('whitehurst'));

    test('conta ELEMENTOS por classe, não soma velocidades', () {
      final b = segmentarSerieBi(
        pontos: [
          p(4800, el: 'V1'), p(4700, el: 'V2'), // Excelente
          p(1500, el: 'V3'), // Ruim
          p(4000, el: 'V4', local: 'Cobertura'), // Ótimo
        ],
        agruparPor: 'local',
        segmentarPor: valorSegmentacaoClassificacao(whitehurst.id),
      );
      expect(b.unidade, 'elementos');
      expect(b.valores['Excelente'], {'Subsolo': 2});
      expect(b.valores['Ruim'], {'Subsolo': 1});
      expect(b.valores['Ótimo'], {'Cobertura': 1});
      // Ordem da escala: da mais grave para a mais branda.
      expect(b.segmentos, ['Ruim', 'Ótimo', 'Excelente']);
      // Cor da própria classe.
      expect(b.cores['Ruim'], whitehurst.classes.first.corTexto);
    });

    test('várias leituras do mesmo elemento contam como UM elemento, pela média', () {
      // 3000 e 4000 → média 3500 → "Bom".
      final b = segmentarSerieBi(
        pontos: [p(3000, el: 'V1'), p(4000, el: 'V1')],
        agruparPor: 'local',
        segmentarPor: valorSegmentacaoClassificacao(whitehurst.id),
      );
      expect(b.valores, {'Bom': {'Subsolo': 1}});
    });

    test('só escalas de uma entrada numérica entram (sem carbonatação, sem inspeção visual)', () {
      final ids = escalasSegmentacaoBi.map((e) => e.id.split(':').first).toSet();
      expect(ids, {'whitehurst', 'resistividade'});
      // Resistividade entra com as três escalas.
      expect(escalasSegmentacaoBi.where((e) => e.id.startsWith('resistividade')), hasLength(3));
    });
  });
}
