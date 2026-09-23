import 'package:diavicon/features/ensaios/ensaios_geral/models/area_ensaio.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/models/ensaio_resumo_model.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/widgets/abas_area_ensaio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  test('lê tipos_ensaio.area sem depender de acento, caixa ou plural', () {
    expect(AreaEnsaio.deBanco('concreto'), AreaEnsaio.concreto);
    expect(AreaEnsaio.deBanco('metálica'), AreaEnsaio.metalica);
    expect(AreaEnsaio.deBanco('Metalica'), AreaEnsaio.metalica);
    expect(AreaEnsaio.deBanco('metálicas'), AreaEnsaio.metalica);
    expect(AreaEnsaio.deBanco('laboratório'), AreaEnsaio.laboratorio);
    expect(AreaEnsaio.deBanco(' LABORATORIO '), AreaEnsaio.laboratorio);
  });

  test('tipo sem área continua aparecendo (em Concreto)', () {
    expect(AreaEnsaio.deBanco(null), AreaEnsaio.concreto);
    expect(AreaEnsaio.deBanco(''), AreaEnsaio.concreto);
    final m = ResumoEnsaioModel.fromJson({'id': '1', 'nome': 'Esclerometria'}, 0, 0);
    expect(m.area, AreaEnsaio.concreto);
  });

  test('o resumo carrega a área vinda do banco', () {
    final m = ResumoEnsaioModel.fromJson({'id': '2', 'nome': 'Líquido penetrante', 'area': 'metálica'}, 0, 0);
    expect(m.area, AreaEnsaio.metalica);
  });

  testWidgets('abas Concreto · Metálicas · Laboratório trocam a seleção', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    var selecionada = AreaEnsaio.concreto;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AbasAreaEnsaio(
            selecionada: selecionada,
            onChanged: (a) => setState(() => selecionada = a),
          ),
        ),
      ),
    ));
    expect(find.text('Concreto'), findsOneWidget);
    expect(find.text('Metálicas'), findsOneWidget);
    expect(find.text('Laboratório'), findsOneWidget);
    await tester.tap(find.text('Metálicas'));
    await tester.pump();
    expect(selecionada, AreaEnsaio.metalica);
  });
}
