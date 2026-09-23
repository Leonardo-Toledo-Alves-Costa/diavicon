import 'package:diavicon/core/widgets/custom_dropdown.dart';
import 'package:diavicon/core/widgets/custom_dropdown_with_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Lista que junta padrão DIAVICON + empresa com o nome como valor: dois
// "Industrial" derrubavam a tela da estrutura (assert do DropdownButton).
List<DropdownMenuItem<String>> _itens(List<String> nomes) =>
    [for (final n in nomes) DropdownMenuItem(value: n, child: Text(n))];

void main() {
  test('remove itens repetidos mantendo o primeiro e a ordem', () {
    final r = itensDropdownSemRepetidos(_itens(['Industrial', 'Residencial', 'Industrial']));
    expect(r.map((i) => i.value), ['Industrial', 'Residencial']);
  });

  test('valor fora da lista vira null em vez de quebrar', () {
    final itens = _itens(['A', 'B']);
    expect(valorDropdownSeguro('B', itens), 'B');
    expect(valorDropdownSeguro('Apagado', itens), isNull);
    expect(valorDropdownSeguro<String>(null, itens), isNull);
  });

  testWidgets('CustomDropdown abre com valor duplicado na lista', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomDropdown<String>(
          label: 'Utilização da estrutura',
          value: 'Industrial',
          items: _itens(['Industrial', 'Industrial', 'Comercial']),
          onChanged: (_) {},
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Industrial'), findsOneWidget);
  });

  testWidgets('CustomDropdownWithAdd abre com valor duplicado na lista', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomDropdownWithAdd<String>(
          label: 'Tipo de estrutura',
          value: 'Industrial',
          items: _itens(['Industrial', 'Industrial']),
          onChanged: (_) {},
          onAddPressed: () {},
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
