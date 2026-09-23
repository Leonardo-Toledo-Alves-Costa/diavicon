import 'package:diavicon/features/empresa/screens/padroes_empresa_screen.dart';
import 'package:diavicon/features/gastos/models/gasto_model.dart';
import 'package:diavicon/features/gastos/providers/gastos_providers.dart';
import 'package:diavicon/features/gastos/screens/categorias_gasto_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('abrir "Nova categoria" não lança exceção', (tester) async {
    final erros = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      // Fonte do Google indisponível offline no teste não interessa aqui.
      if (d.exceptionAsString().contains('GoogleFonts') || d.exceptionAsString().contains('google_fonts')) return;
      erros.add(d);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ehAdminEmpresaProvider.overrideWithValue(true),
        categoriasGastoProvider.overrideWith((ref) async => const [
              CategoriaGastoModel(id: '1', empresaId: 'e1', nome: 'Transporte'),
            ]),
      ],
      // Mesma pilha do app: Padrões da empresa → Categorias de gasto.
      child: const MaterialApp(home: PadroesEmpresaScreen(empresaId: 'e1')),
    ));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Categorias de gasto'), 200);
    await tester.tap(find.text('Categorias de gasto'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nova categoria'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    for (final e in erros) {
      // ignore: avoid_print
      print('ERRO: ${e.exceptionAsString()}\n${e.stack}');
    }
    expect(erros, isEmpty);
    expect(find.text('Nova categoria'), findsWidgets);

    // Teclado subindo (autofocus): o Flutter reconstrói a pilha com o novo
    // viewInsets — no aparelho isso acontece logo que o diálogo abre.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    for (final e in erros) {
      // ignore: avoid_print
      print('ERRO (teclado): ${e.exceptionAsString()}\n${e.stack}');
    }
    expect(erros, isEmpty);

    // Digitar e cancelar também não pode quebrar (descarte do controller).
    await tester.enterText(find.byType(TextField), 'Estacionamento');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(erros, isEmpty);
  });
}
