import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('providers de projetos não executam I/O nem definem controllers', () {
    final providerDirectory = Directory('lib/features/projetos/providers');
    final providerFiles = providerDirectory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.dart'),
    );

    for (final file in providerFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('package:supabase_flutter')),
        reason: '${file.path} deve delegar I/O a um repository.',
      );
      expect(
        source,
        isNot(matches(RegExp(r'class\s+\w+Controller\b'))),
        reason: '${file.path} deve manter controllers em controllers/.',
      );
    }
  });

  test('widgets compartilhados de perfil pertencem ao app shell', () {
    expect(
      File('lib/features/app_shell/widgets/perfil_header.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/features/app_shell/widgets/perfil_drawer.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/features/home/screens/perfil_dados_screen.dart').existsSync(),
      isTrue,
    );
    expect(
      File('lib/features/home/widgets/perfil_header.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/home/widgets/perfil_drawer.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/home/screens/perfil_header.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/home/screens/perfil_drawer.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/features/home/screens/perfil_Screen.dart').existsSync(),
      isFalse,
    );
  });

  test('app bar compartilhada não depende de Projetos', () {
    final file = File('lib/core/widgets/custom_appbar.dart');
    final source = file.readAsStringSync();

    expect(source, isNot(contains('features/projetos')));
  });

  test('notificações globais não dependem da feature Projetos', () {
    const movedFiles = <String>[
      'lib/features/notificacoes/repositories/notificacoes_repository.dart',
      'lib/features/notificacoes/providers/notificacoes_provider.dart',
      'lib/features/notificacoes/controllers/notificacoes_controller.dart',
      'lib/features/notificacoes/screens/notificacoes_screen.dart',
    ];
    const obsoleteFiles = <String>[
      'lib/features/projetos/repositories/notificacoes_repository.dart',
      'lib/features/projetos/providers/notificacoes_provider.dart',
      'lib/features/projetos/controllers/notificacoes_controller.dart',
      'lib/features/projetos/screens/notificacoes_screen.dart',
    ];

    for (final path in movedFiles) {
      expect(File(path).existsSync(), isTrue, reason: '$path deve existir.');
    }
    for (final path in obsoleteFiles) {
      expect(File(path).existsSync(), isFalse, reason: '$path foi movido.');
    }

    final notificationFiles = Directory('lib/features/notificacoes')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in notificationFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(
          matches(
            RegExp(
              r'''(?:package:diavicon/features/projetos|(?:\.\./)+projetos/)''',
            ),
          ),
        ),
        reason: '${file.path} deve receber ações específicas por injeção.',
      );
    }

    final providerSource = File(
      'lib/features/notificacoes/providers/notificacoes_provider.dart',
    ).readAsStringSync();
    expect(providerSource, isNot(contains('package:supabase_flutter')));
  });
}
