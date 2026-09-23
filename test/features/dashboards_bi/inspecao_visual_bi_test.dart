import 'package:diavicon/features/dashboards_bi/models/bi_data_point.dart';
import 'package:diavicon/features/dashboards_bi/models/campos_bi_catalogo.dart';
import 'package:diavicon/features/dashboards_bi/models/serie_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/repositories/dashboard_bi_repository.dart';
import 'package:diavicon/features/dashboards_bi/utils/classificadores_bi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um ponto por ANOMALIA, como o fetcher da inspeção visual devolve.
BiDataPoint anomalia(double gut, {String el = 'e1', String local = 'Subsolo', String tipo = 'Viga', String estrutura = 'Torre A'}) =>
    BiDataPoint(elementoId: el, elementoNome: el, tipoElemento: tipo, local: local, estrutura: estrutura, valor: gut);

void main() {
  group('GUT somado', () {
    test('o campo GUT soma no agrupamento; medições continuam por média', () {
      expect(buscarCampoBi('inspecao_visual', 'pontuacao_gut')!.agregacao, AgregacaoBi.soma);
      for (final c in ['gravidade', 'urgencia', 'tendencia']) {
        expect(buscarCampoBi('inspecao_visual', c)!.agregacao, AgregacaoBi.soma, reason: c);
      }
      expect(buscarCampoBi('ultrassom', 'velocidade_longitudinal')!.agregacao, AgregacaoBi.media);
    });

    test('um local com muitas anomalias pesa mais que um com uma só', () {
      final pontos = [
        anomalia(40, local: 'Subsolo'),
        anomalia(40, local: 'Subsolo'),
        anomalia(40, local: 'Subsolo'),
        anomalia(40, local: 'Cobertura'),
      ];
      final soma = agruparValoresBi(pontos, 'local', agregacao: AgregacaoBi.soma);
      expect(soma, {'Subsolo': 120, 'Cobertura': 40});
      // Com a média de antes os dois locais empatavam em 40.
      expect(agruparValoresBi(pontos, 'local'), {'Subsolo': 40, 'Cobertura': 40});
    });

    test('bate com o somatório do relatório por elemento e por tipo', () {
      final pontos = [anomalia(10, el: 'V1'), anomalia(5, el: 'V1'), anomalia(7, el: 'P1', tipo: 'Pilar')];
      expect(agruparValoresBi(pontos, 'elemento', agregacao: AgregacaoBi.soma), {'V1': 15, 'P1': 7});
      expect(agruparValoresBi(pontos, 'tipoElemento', agregacao: AgregacaoBi.soma), {'Viga': 15, 'Pilar': 7});
    });

    test('agrupa por estrutura (dashboard de projeto)', () {
      final pontos = [anomalia(10, estrutura: 'Torre A'), anomalia(20, estrutura: 'Torre B'), anomalia(5, estrutura: 'Torre A')];
      expect(agruparValoresBi(pontos, 'estrutura', agregacao: AgregacaoBi.soma), {'Torre A': 15, 'Torre B': 20});
    });

    test('ponto sem estrutura vai para "Desconhecida", não some', () {
      final pontos = [BiDataPoint(elementoId: 'x', elementoNome: 'x', tipoElemento: 'Viga', local: 'L', valor: 3)];
      expect(agruparValoresBi(pontos, 'estrutura'), {'Desconhecida': 3});
    });

    test('equação agrega por média mesmo com fonte de soma na lista', () {
      expect(DashboardBiRepository.agregacaoDe(const ReferenciaValorBi(variavelId: 'v')), AgregacaoBi.media);
      expect(
        DashboardBiRepository.agregacaoDe(const ReferenciaValorBi(fonte: 'inspecao_visual', campo: 'pontuacao_gut')),
        AgregacaoBi.soma,
      );
    });
  });

  group('badge de risco da inspeção visual', () {
    final badge = buscarClassificadorBi('inspecao_visual_risco')!;
    BiDataPoint risco(String c) => BiDataPoint(elementoId: 'e', elementoNome: 'e', tipoElemento: 'V', local: 'L', categoria: c);

    test('conta anomalias por tipo de risco e intensidade', () {
      final r = distribuirBadge(badge, {
        'risco': [
          risco('Humano · Alto'),
          risco('Humano · Alto'),
          risco('Humano · Baixo'),
          risco('Material · Médio'),
        ],
      });
      expect(r.dimensoes.map((d) => d.dimensao.nome), ['Humano', 'Material', 'Ambiental']);
      final humano = r.dimensoes[0];
      expect(humano.contagens.map((c) => '${c.quantidade} ${c.classe.texto}'), ['2 Alto', '1 Baixo']);
      expect(r.dimensoes[1].contagens.single.classe.texto, 'Médio');
      expect(r.dimensoes[2].contagens, isEmpty);
    });

    test('alto é a classe mais grave (vermelha), baixo a mais branda', () {
      final r = distribuirBadge(badge, {'risco': [risco('Ambiental · Alto'), risco('Ambiental · Baixo')]});
      final c = r.dimensoes[2].contagens;
      expect(c.first.classe.texto, 'Alto');
      expect(c.first.classe.posicao, lessThan(c.last.classe.posicao));
    });

    test('sem anomalias o badge fica vazio', () {
      expect(distribuirBadge(badge, {'risco': []}).vazio, isTrue);
    });
  });
}
