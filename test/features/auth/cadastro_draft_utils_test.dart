import 'package:diavicon/features/auth/utils/cadastro_draft_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CadastroDraftUtils.resolve', () {
    test('prefere o rascunho persistido ao extra da rota', () {
      final draft = CadastroDraftUtils.resolve(
        persisted: {'email': 'persistido@example.com'},
        routeExtra: {'email': 'rota@example.com'},
      );

      expect(draft, {'email': 'persistido@example.com'});
    });

    test('converte mapas não tipados vindos da rota', () {
      final draft = CadastroDraftUtils.resolve(
        persisted: const {},
        routeExtra: {1: 'valor', 'email': 'user@example.com'},
      );

      expect(draft, {'1': 'valor', 'email': 'user@example.com'});
    });

    test('retorna mapa vazio quando não há dados', () {
      expect(
        CadastroDraftUtils.resolve(persisted: const {}, routeExtra: null),
        equals(<String, dynamic>{}),
      );
    });
  });

  group('CadastroDraftUtils.hasCredentials', () {
    test('aceita senha no campo legado password', () {
      expect(
        CadastroDraftUtils.hasCredentials({
          'email': 'user@example.com',
          'password': 'secret',
        }),
        equals(true),
      );
    });

    test('recusa credenciais ausentes ou vazias', () {
      expect(CadastroDraftUtils.hasCredentials({}), equals(false));
      expect(
        CadastroDraftUtils.hasCredentials({'email': 'user@example.com'}),
        equals(false),
      );
      expect(
        CadastroDraftUtils.hasCredentials({'email': '  ', 'senha': 'secret'}),
        equals(false),
      );
    });
  });
}
