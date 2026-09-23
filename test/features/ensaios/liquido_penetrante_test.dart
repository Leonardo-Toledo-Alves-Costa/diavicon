import 'package:diavicon/features/ensaios/ensaio_liquido_penetrante/models/liquido_penetrante_model.dart';
import 'package:diavicon/features/ensaios/ensaio_liquido_penetrante/reports/modelo/lp_modelo_report_data.dart';
import 'package:diavicon/features/ensaios/ensaio_liquido_penetrante/widgets/lp_widgets.dart';
import 'package:diavicon/features/modelos_relatorios/models/ensaio_modelo_config.dart';
import 'package:diavicon/features/modelos_relatorios/models/modelo_relatorio_schema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PontoLiquidoPenetranteModel _p(String nome, StatusLP? s, {String tamanho = '15', String? foto}) =>
    PontoLiquidoPenetranteModel(nomePonto: nome, status: s, tamanhoAnalise: tamanho, fotoSolda: foto);

void main() {
  group('status', () {
    test('lê a chave gravada ou o rótulo, com ou sem acento', () {
      expect(StatusLP.fromChave('aprovado'), StatusLP.aprovado);
      expect(StatusLP.fromChave('Reprovado'), StatusLP.reprovado);
      expect(StatusLP.fromChave('cabe_analise'), StatusLP.cabeAnalise);
      expect(StatusLP.fromChave('Cabe análise'), StatusLP.cabeAnalise);
      expect(StatusLP.fromChave(null), isNull);
      expect(StatusLP.fromChave(''), isNull);
    });
  });

  group('badge do elemento (valor_resultado / cor_resultado)', () {
    test('conta por status e mostra só os que existem', () {
      final c = ContagemStatusLP.de([StatusLP.aprovado, StatusLP.aprovado, StatusLP.reprovado, StatusLP.cabeAnalise]);
      expect((c.aprovados, c.reprovados, c.cabeAnalise, c.total), (2, 1, 1, 4));
      expect(c.textoBadge, '2 aprov. · 1 reprov. · 1 análise');
      expect(ContagemStatusLP.de([StatusLP.aprovado, StatusLP.aprovado]).textoBadge, '2 aprov.');
    });

    test('cor = pior status: reprovado > cabe análise > aprovado', () {
      expect(ContagemStatusLP.de([StatusLP.aprovado, StatusLP.reprovado]).pior, StatusLP.reprovado);
      expect(ContagemStatusLP.de([StatusLP.aprovado, StatusLP.cabeAnalise]).pior, StatusLP.cabeAnalise);
      expect(ContagemStatusLP.de([StatusLP.aprovado]).pior, StatusLP.aprovado);
      expect(ContagemStatusLP.de([StatusLP.reprovado]).corHex, '#C62828');
    });

    test('sem pontos com status = Pendente/cinza', () {
      final c = ContagemStatusLP.de(const []);
      expect(c.textoBadge, 'Pendente');
      expect(c.corHex, '#E0E0E0');
      expect(ContagemStatusLP.de([null]).textoBadge, 'Pendente');
    });

    test('soma contagens (análise geral)', () {
      final a = ContagemStatusLP.de([StatusLP.aprovado]);
      final b = ContagemStatusLP.de([StatusLP.reprovado, StatusLP.aprovado]);
      final t = a + b;
      expect((t.aprovados, t.reprovados, t.total), (2, 1, 3));
    });
  });

  test('grava nas colunas reais da tabela', () {
    final json = _p('Cordão C-01', StatusLP.cabeAnalise).toJson(pontoGeralId: 'g1');
    expect(json['ponto_id'], 'g1');
    expect(json['nome_ponto'], 'Cordão C-01');
    expect(json['status'], 'cabe_analise');
    expect(json.keys, containsAll(['foto_solda', 'foto_penetrante', 'foto_resultado', 'tamanho_analise', 'tempo_penetracao', 'descricao']));
  });

  test('resumo do card: "15 cm analisados · 1 foto"', () {
    expect(_p('C', StatusLP.aprovado, foto: 'http://x/1.jpg').resumo, '15 cm analisados · 1 foto');
  });

  group('relatório', () {
    final dados = LPModeloReportData(SupabaseClient('http://localhost', 'anon'));
    final elementos = [
      ElementoLPBruto(
        nomeElemento: 'Viga V07',
        tipoElemento: 'Viga',
        local: 'Cobertura',
        marcacaoImagemUrl: null,
        nomeEnsaio: 'LP V07',
        pontos: [_p('C-01', StatusLP.aprovado, foto: 'http://x/s.jpg'), _p('C-02', StatusLP.reprovado)],
        galeriaGeral: const [],
      ),
      ElementoLPBruto(
        nomeElemento: 'Viga V08',
        tipoElemento: 'Viga',
        local: 'Cobertura',
        marcacaoImagemUrl: null,
        nomeEnsaio: 'LP V08',
        pontos: [_p('C-01', StatusLP.cabeAnalise)],
        galeriaGeral: const [],
      ),
    ];

    test('um registro por elemento, com os pontos de LP como sub-lista', () {
      final r = dados.montarRegistros(elementos);
      expect(r, hasLength(2));
      expect(r.first.dados['nome_elemento_lp'], 'Viga V07');
      expect(r.first.dados['resultado_lp'], '1 aprov. · 1 reprov.');
      expect(r.first.pontos.map((p) => p['nome_ponto_lp']), ['C-01', 'C-02']);
      expect(r.first.pontos.first['tamanho_ponto_lp'], '15 cm');
      expect(r.first.pontos.first['foto_solda_lp'], 'http://x/s.jpg');
      expect(r.first.pontos.last.containsKey('foto_solda_lp'), isFalse);
      expect(r.first.fotos, hasLength(1));
    });

    test('agrupado por local soma elementos e pontos', () {
      final linhas = dados.linhasAgrupadas(elementos: elementos, hierarquia: HierarquiaAgrupamento.local);
      expect(linhas, hasLength(1));
      expect(linhas.first['total_elementos_grupo_lp'], '2');
      expect(linhas.first['total_pontos_grupo_lp'], '3');
      expect(linhas.first['reprovados_grupo_lp'], '1');
    });

    test('editor de modelos reconhece o ensaio pelo nome', () {
      final cfg = resolverEnsaioModeloConfig('Líquido penetrante');
      expect(cfg, isNotNull);
      expect(cfg!.rotuloSubListaRegistro, 'Pontos de LP');
    });
  });

  testWidgets('resumo da contagem mostra os três status', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ResumoContagemLP(contagem: ContagemStatusLP.de([StatusLP.aprovado, StatusLP.reprovado]))),
    ));
    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.text('Reprovado'), findsOneWidget);
    expect(find.text('Cabe análise'), findsOneWidget);
    expect(find.text('2 pontos'), findsOneWidget);
  });
}
