import 'dart:convert';

import 'package:diavicon/features/dashboards_bi/models/dashboard_card_model.dart';
import 'package:diavicon/features/dashboards_bi/models/serie_bi_model.dart';
import 'package:diavicon/features/dashboards_bi/utils/formato_bi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ida e volta pelo JSON do schema — o caminho real de salvar e reabrir um
/// dashboard (inclusive a passagem por jsonEncode, como no Supabase).
DashboardCardModel idaEVolta(DashboardCardModel c) {
  final json = jsonDecode(jsonEncode(cardsParaSchemaJson([c]))) as Map<String, dynamic>;
  return cardsFromSchemaJson(json).single;
}

void main() {
  group('persistência', () {
    test('gráfico personalizado volta com todas as séries', () {
      final c = idaEVolta(const DashboardCardModel(
        id: 'c1', tipo: TipoCardBi.grafico, gridX: 0, gridY: 0, largura: 3, altura: 2,
        tipoGrafico: TipoGraficoBi.personalizado,
        agruparPor: 'local',
        series: [
          SerieBi(id: 's1', nome: 'Velocidade', valor: ReferenciaValorBi(fonte: 'ultrassom', campo: 'velocidade_longitudinal', estatistica: 'media'), eixo: 1, tipo: TipoSerieBi.barra, cor: 0xFF2F6FED),
          SerieBi(id: 's2', nome: '', valor: ReferenciaValorBi(variavelId: 'v-sonreb'), eixo: 2, tipo: TipoSerieBi.linha, cor: 0xFFE0526B),
        ],
      ));

      expect(c.tipoGrafico, TipoGraficoBi.personalizado);
      expect(c.usaSeries, isTrue);
      expect(c.agruparPor, 'local');
      expect(c.series.map((s) => s.id), ['s1', 's2']);
      expect(c.series[1].eixo, 2);
      expect(c.series[1].tipo, TipoSerieBi.linha);
      expect(c.series[1].valor.variavelId, 'v-sonreb');
      expect(c.series[0].valor.estatistica, 'media');
    });

    test('tabela volta com colunas na ordem, títulos e regras de cor', () {
      final c = idaEVolta(const DashboardCardModel(
        id: 'c2', tipo: TipoCardBi.tabela, gridX: 0, gridY: 0, largura: 3, altura: 2,
        agruparPor: 'elemento',
        colunas: [
          ColunaTabelaBi(id: 'b', titulo: 'ρ médio', valor: ReferenciaValorBi(fonte: 'resistividade', campo: 'resistividade', estatistica: 'media'), regras: [
            RegraCorBi(operador: OperadorRegraBi.menorOuIgual, valor: 15, cor: 0xFFD32F2F),
            RegraCorBi(operador: OperadorRegraBi.entre, valor: 15, valor2: 55, cor: 0xFFF9A825),
          ]),
          ColunaTabelaBi(id: 'a', titulo: 'CV', valor: ReferenciaValorBi(fonte: 'resistividade', campo: 'resistividade', estatistica: 'coefVariacao')),
        ],
      ));

      // A ordem definida pelo usuário é a da lista, não a dos ids.
      expect(c.colunas.map((x) => x.titulo), ['ρ médio', 'CV']);
      expect(c.colunas.first.regras, hasLength(2));
      expect(c.colunas.first.regras[1].valor2, 55);
    });

    test('badge volta com a classificação', () {
      final c = idaEVolta(const DashboardCardModel(
        id: 'c3', tipo: TipoCardBi.badge, gridX: 0, gridY: 0, largura: 3, altura: 2, classificacaoId: 'carbonatacao',
      ));
      expect(c.tipo, TipoCardBi.badge);
      expect(c.classificacaoId, 'carbonatacao');
    });

    test('card antigo, sem os campos novos, continua abrindo', () {
      final c = cardsFromSchemaJson({
        'cards': [
          {'id': 'x', 'tipo': 'grafico', 'tipoGrafico': 'barra', 'fonteChave': 'ultrassom', 'campoX': 'fck'},
        ],
      }).single;
      expect(c.series, isEmpty);
      expect(c.colunas, isEmpty);
      expect(c.usaSeries, isFalse);
    });
  });

  group('regras de cor', () {
    const coluna = ColunaTabelaBi(id: 'c', titulo: 'ρ', valor: ReferenciaValorBi(), regras: [
      RegraCorBi(operador: OperadorRegraBi.menorOuIgual, valor: 15, cor: 1),
      RegraCorBi(operador: OperadorRegraBi.entre, valor: 15, valor2: 55, cor: 2),
      RegraCorBi(operador: OperadorRegraBi.maiorQue, valor: 55, cor: 3),
    ]);

    test('a primeira regra que vale é a que pinta', () {
      // 15 casa nas duas primeiras; vale a primeira.
      expect(coluna.corPara(15)?.toARGB32(), 1);
      expect(coluna.corPara(30)?.toARGB32(), 2);
      expect(coluna.corPara(80)?.toARGB32(), 3);
    });

    test('célula sem valor não é pintada', () {
      expect(coluna.corPara(null), isNull);
    });

    test('"entre" aceita os limites em qualquer ordem e é inclusivo', () {
      const r = RegraCorBi(operador: OperadorRegraBi.entre, valor: 55, valor2: 15, cor: 0);
      expect(r.aplica(15), isTrue);
      expect(r.aplica(55), isTrue);
      expect(r.aplica(14.9), isFalse);
    });
  });

  group('formatação', () {
    test('padrão brasileiro, casas proporcionais à grandeza', () {
      expect(formatarNumeroBi(4210.4), '4.210');
      expect(formatarNumeroBi(152.34), '152,3');
      expect(formatarNumeroBi(12.345), '12,35');
      expect(formatarNumeroBi(-1234.0), '-1.234');
      expect(formatarNumeroBi(null), '—');
    });

    test('ordem natural dos elementos: V2 antes de V10', () {
      final l = ['V10', 'V2', 'P1', 'V1']..sort(compararRotulosBi);
      expect(l, ['P1', 'V1', 'V2', 'V10']);
    });
  });
}
