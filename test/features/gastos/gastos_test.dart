import 'package:diavicon/features/gastos/models/gasto_model.dart';
import 'package:diavicon/features/gastos/reports/gastos_html_builder.dart';
import 'package:diavicon/features/gastos/repositories/gastos_repository.dart';
import 'package:diavicon/features/gastos/utils/agregacao_gastos.dart';
import 'package:diavicon/features/gastos/utils/gastos_csv.dart';
import 'package:flutter_test/flutter_test.dart';

GastoModel _gasto({
  String id = 'g',
  String usuario = 'u1',
  String usuarioNome = 'Fulano Ciclano',
  String projeto = 'p1',
  String projetoNome = 'Projeto 001',
  String categoria = 'c1',
  String categoriaNome = 'Ferramentas',
  bool reembolsavel = true,
  double valor = 100,
  DateTime? data,
}) =>
    GastoModel(
      id: id,
      empresaId: 'e1',
      usuarioId: usuario,
      usuarioNome: usuarioNome,
      projetoId: projeto,
      projetoNome: projetoNome,
      categoriaId: categoria,
      categoriaNome: categoriaNome,
      reembolsavel: reembolsavel,
      valor: valor,
      data: data ?? DateTime(2026, 9, 10),
      meioPagamento: MeioPagamento.credito,
    );

void main() {
  group('formatação', () {
    test('moeda em reais com milhar e centavos', () {
      expect(formatarMoeda(12400), 'R\$ 12.400,00');
      expect(formatarMoeda(12400, centavos: false), 'R\$ 12.400');
      expect(formatarMoeda(48), 'R\$ 48,00');
      expect(formatarMoeda(1234567.5), 'R\$ 1.234.567,50');
    });

    test('arredonda em centavos uma vez só (12,999 vira 13,00)', () {
      expect(formatarMoeda(12.999), 'R\$ 13,00');
      expect(formatarMoeda(0.1 + 0.2), 'R\$ 0,30');
    });

    test('lê o valor digitado nos formatos que o usuário usa', () {
      expect(lerValorDigitado('48'), 48);
      expect(lerValorDigitado('48,50'), 48.5);
      expect(lerValorDigitado('1.234,56'), 1234.56);
      expect(lerValorDigitado('1.234'), 1234); // milhar, não 1,234
      expect(lerValorDigitado('48.50'), 48.5);
      expect(lerValorDigitado('R\$ 22,00'), 22);
      expect(lerValorDigitado(''), isNull);
      expect(lerValorDigitado('abc'), isNull);
    });
  });

  group('mapeamento para as tabelas reais', () {
    test('valor bigint em centavos, nos dois sentidos', () {
      expect(GastoModel.paraCentavos(48.5), 4850);
      expect(GastoModel.paraCentavos(0.1 + 0.2), 30);
      final g = GastoModel.fromMap({'id': 'x', 'valor': 4850, 'criado_em': '2026-09-22T15:00:00+00:00'});
      expect(g.valor, 48.5);
    });

    test('a data do gasto vai em criado_em ao meio-dia local e volta no mesmo dia', () {
      final iso = GastoModel.dataParaCriadoEm(DateTime(2026, 9, 22));
      final lido = GastoModel.fromMap({'id': 'x', 'valor': 1, 'criado_em': iso});
      expect((lido.data.year, lido.data.month, lido.data.day), (2026, 9, 22));
    });

    test('grava só colunas que existem, com os nomes reais', () {
      final dados = GastoModel.dadosParaGravar(
        projetoId: 'p',
        categoriaId: 'c',
        reembolsavel: true,
        valor: 10.005,
        data: DateTime(2026, 9, 2),
        meioPagamento: MeioPagamento.aVista,
      );
      expect(dados.keys.toSet(), {'projeto_id', 'categoria', 'reembolsavel', 'valor', 'criado_em', 'meio', 'anexo_url', 'anexo_tipo'});
      expect(dados['meio'], 'a_vista');
      expect(dados['valor'], 1001);
    });

    test('lê os joins e os nomes reais das colunas', () {
      final g = GastoModel.fromMap({
        'id': 'x',
        'empresa_id': 'e1',
        'criado_por': 'u9',
        'projeto_id': 'p',
        'categoria': 'c',
        'valor': 2200,
        'criado_em': '2026-09-22T15:00:00+00:00',
        'meio': 'boleto',
        'reembolsavel': false,
        'anexo_url': 'https://x.supabase.co/storage/v1/object/public/projetos/gastos/e1/u9/1.jpg',
        'anexo_tipo': 'foto',
        'projetos': {'nome': 'Projeto 001'},
        'categoria_gastos': {'nome': 'Ferramentas'},
        'usuarios': {'nome': 'Fulano', 'sobrenome': 'Ciclano'},
      });
      expect(g.usuarioId, 'u9');
      expect(g.usuarioNome, 'Fulano Ciclano');
      expect(g.categoriaNome, 'Ferramentas');
      expect(g.meioPagamento, MeioPagamento.boleto);
      expect(g.anexoTipo, TipoAnexoGasto.foto);
    });

    test('caminho do comprovante a partir da URL pública', () {
      expect(
        GastosRepository.caminhoDoAnexo('https://x.supabase.co/storage/v1/object/public/projetos/gastos/e1/u9/1.jpg'),
        'gastos/e1/u9/1.jpg',
      );
      expect(GastosRepository.caminhoDoAnexo('https://outro/lugar.jpg'), isNull);
    });

    test('nome de categoria repetido é detectado sem diferenciar maiúsculas', () {
      const cats = [CategoriaGastoModel(id: '1', empresaId: 'e', nome: 'Transporte')];
      expect(categoriaComNome(cats, '  transporte ')?.id, '1');
      expect(categoriaComNome(cats, 'Pedágio'), isNull);
    });
  });

  group('agregação', () {
    final gastos = [
      _gasto(id: '1', valor: 2200, categoria: 'c1', categoriaNome: 'Ferramentas'),
      _gasto(id: '2', valor: 1800, categoria: 'c2', categoriaNome: 'Transporte', reembolsavel: false),
      _gasto(id: '3', valor: 1400, categoria: 'c3', categoriaNome: 'Hospedagem', projeto: 'p2', projetoNome: 'Torre B'),
      _gasto(id: '4', valor: 3800, usuario: 'u2', usuarioNome: 'Beltrano Souza', projeto: 'p2', projetoNome: 'Torre B'),
    ];

    test('totais separam reembolsável e não reembolsável', () {
      final t = AgregacaoGastos.totais(gastos);
      expect(t.total, 9200);
      expect(t.reembolsavel, 7400);
      expect(t.naoReembolsavel, 1800);
    });

    test('ranking por usuário do maior para o menor, com a divisão por reembolso', () {
      final r = AgregacaoGastos.porUsuario(gastos);
      expect(r.map((i) => i.rotulo), ['Fulano Ciclano', 'Beltrano Souza']);
      expect(r.first.valor, 5400);
      expect(r.first.reembolsavel, 3600);
      expect(r.first.naoReembolsavel, 1800);
    });

    test('ranking por projeto e por categoria', () {
      expect(AgregacaoGastos.porProjeto(gastos).map((i) => (i.rotulo, i.valor)), [('Torre B', 5200.0), ('Projeto 001', 4000.0)]);
      expect(AgregacaoGastos.porCategoria(gastos).first.rotulo, 'Ferramentas');
    });

    test('últimos meses em ordem cronológica, com zero nos meses vazios e virada de ano', () {
      final g = [
        _gasto(valor: 10, data: DateTime(2025, 12, 5)),
        _gasto(valor: 20, data: DateTime(2026, 2, 1)),
        _gasto(valor: 5, data: DateTime(2026, 2, 28)),
      ];
      final meses = AgregacaoGastos.ultimosMeses(g, DateTime(2026, 2));
      expect(meses.map((m) => (m.mes.year, m.mes.month)), [(2025, 11), (2025, 12), (2026, 1), (2026, 2)]);
      expect(meses.map((m) => m.valor), [0, 10, 0, 25]);
      expect(rotuloMesCurto(meses.last.mes), 'Fev');
    });
  });

  test('só o autor edita (o admin vê, mas não altera gasto de terceiro)', () {
    expect(_gasto().podeEditar('u1'), isTrue);
    expect(_gasto().podeEditar('u2'), isFalse);
    expect(_gasto().podeEditar(null), isFalse);
  });

  test('CSV: separador ; , vírgula decimal, BOM e aspas quando preciso', () {
    final csv = GastosCsv.gerar([_gasto(valor: 1234.5, projetoNome: 'Obra "A"; bloco 2')]);
    expect(csv.startsWith('﻿'), isTrue);
    final linhas = csv.substring(1).trim().split('\r\n');
    expect(linhas.first, 'Data;Projeto;Categoria;Usuário;Valor (R\$);Reembolsável;Meio de pagamento');
    expect(linhas[1], '10/09/2026;"Obra ""A""; bloco 2";Ferramentas;Fulano Ciclano;1234,50;Sim;Crédito');
  });

  group('HTML', () {
    test('tem os totais, a tabela e escapa o texto do usuário', () {
      final html = GastosHtmlBuilder.montar(
        empresaNome: 'Empresa <X>',
        inicio: DateTime(2026, 9, 1),
        fim: DateTime(2026, 9, 18),
        gastos: [_gasto(valor: 100, projetoNome: '<script>alert(1)</script>'), _gasto(valor: 50, reembolsavel: false)],
        geradoEm: DateTime(2026, 9, 18),
      );
      expect(html, contains('Período: 01/09/2026 a 18/09/2026'));
      expect(html, contains('Empresa &lt;X&gt;'));
      expect(html, isNot(contains('<script>')));
      expect(html, contains('R\$ 150,00'));
      expect(html, contains('R\$ 100,00'));
    });

    test('período sem gastos não quebra', () {
      final html = GastosHtmlBuilder.montar(empresaNome: 'E', inicio: DateTime(2026), fim: DateTime(2026), gastos: const []);
      expect(html, contains('Nenhum gasto no período.'));
    });
  });
}
