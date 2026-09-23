import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String repository;
  late String clientRepository;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations_manual/20260903120000_harden_home_projects_rls.sql',
    );
    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    repository = File(
      'lib/features/projetos/repositories/project_repository.dart',
    ).readAsStringSync();
    clientRepository = File(
      'lib/features/projetos/repositories/clientes_projeto_repository.dart',
    ).readAsStringSync();
  });

  test('operações sensíveis de projeto usam RPCs atômicas', () {
    const rpcNames = <String>[
      'create_project',
      'update_project',
      'invite_project_company',
      'respond_to_project_company_invite',
      'transfer_project_management',
      'invite_project_client',
      'respond_to_project_client_invite',
      'remove_project_client',
      'delete_project',
    ];

    for (final name in rpcNames) {
      expect(
        migration,
        contains('create or replace function public.$name('),
        reason: 'A migration deve versionar a RPC $name.',
      );
    }

    expect(repository, matches(RegExp(r"\.rpc\(\s*'create_project'")));
    expect(repository, matches(RegExp(r"\.rpc\(\s*'update_project'")));
    expect(repository, matches(RegExp(r"\.rpc\(\s*'delete_project'")));
    expect(clientRepository, contains("'invite_project_client'"));
    expect(clientRepository, contains("'respond_to_project_client_invite'"));
    expect(clientRepository, contains("'remove_project_client'"));
    expect(
      repository,
      isNot(
        matches(RegExp(r"\.from\('projetos'\)\s*\.update\(", multiLine: true)),
      ),
    );
  });

  test('update direto de projetos permanece fechado', () {
    expect(
      migration,
      isNot(
        matches(
          RegExp(
            r'grant\s+update\s*\([^;]+\)\s+on\s+table\s+public\.projetos',
            caseSensitive: false,
          ),
        ),
      ),
    );
    expect(
      migration,
      matches(
        RegExp(
          r'create policy dv_projects_update_guard[\s\S]+?using \(false\)[\s\S]+?with check \(false\);',
          caseSensitive: false,
        ),
      ),
    );
    expect(
      migration,
      matches(
        RegExp(
          r'create policy dv_projects_delete_guard[\s\S]+?using \(false\);',
          caseSensitive: false,
        ),
      ),
    );
  });

  test('cliente pendente não recebe acesso antes do aceite', () {
    expect(migration, contains("p.status_vinculo_cliente = 'ativo'"));
    expect(
      migration,
      contains("values (v_actor_company_id, p_client_company_id, 'pendente')"),
    );
    expect(migration, contains("n.tipo = 'convite_cliente'"));
  });

  test('namespace novo do Storage não bloqueia os demais módulos', () {
    expect(
      migration,
      contains(
        "coalesce((storage.foldername(name))[3], '') not in ('capas', 'clientes')",
      ),
    );
    expect(migration, contains("and p.prokind = 'f'"));
  });

  test('auditoria é somente leitura e acompanha a RPC de edição', () {
    final audit = File(
      'supabase/audit_home_projects_rls.sql',
    ).readAsStringSync();

    expect(audit, contains('begin transaction read only;'));
    expect(audit, contains("'update_project'"));
    expect(audit, contains("'respond_to_project_client_invite'"));
    expect(audit.trimRight(), endsWith('commit;'));
  });
}
