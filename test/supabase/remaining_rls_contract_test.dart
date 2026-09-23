import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath = 'supabase/migrations/20260909100000_remaining_rls.sql';
const _projectTeamAccessPath =
    'supabase/migrations/20260902180000_project_team_access.sql';
const _homeProjectsPath =
    'supabase/migrations/20260903120000_harden_home_projects_rls.sql';
const _projectTeamFollowupPath =
    'supabase/migrations/20260908020000_project_team_rls_followup.sql';
const _visualFeaturePath = 'lib/features/ensaios/ensaios_inspecao_visual';
const _projectRepositoryPath =
    'lib/features/projetos/repositories/project_repository.dart';

String _stripSqlComments(String sql) {
  return sql
      .replaceAll(RegExp(r'--[^\r\n]*'), '')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ');
}

String _compactSql(String sql) {
  return _stripSqlComments(sql).replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

List<String> _policyStatements(String sql) {
  return RegExp(
    r'create\s+policy\b[\s\S]*?;',
    caseSensitive: false,
  ).allMatches(_stripSqlComments(sql)).map((match) => match.group(0)!).toList();
}

String _policyFor(String sql, String name, String table) {
  final match = RegExp(
    r'create\s+policy\s+' +
        RegExp.escape(name) +
        r'\s+on\s+public\.' +
        RegExp.escape(table) +
        r'\b[\s\S]*?;',
    caseSensitive: false,
  ).firstMatch(_stripSqlComments(sql));

  expect(
    match,
    isNotNull,
    reason: 'Policy $name em public.$table não foi encontrada.',
  );
  return match!.group(0)!;
}

String _functionBlock(String sql, String name) {
  final source = _stripSqlComments(sql);
  final functionPattern = RegExp(
    r'create\s+or\s+replace\s+function\s+public\.' +
        RegExp.escape(name) +
        r'\b',
    caseSensitive: false,
  );
  final matches = functionPattern.allMatches(source).toList();
  final startMatch = matches.isEmpty ? null : matches.last;
  expect(startMatch, isNotNull, reason: 'RPC public.$name não foi encontrada.');

  final start = startMatch!.start;
  final nextFunction = RegExp(
    r'\ncreate\s+or\s+replace\s+function\s+public\.',
    caseSensitive: false,
  ).firstMatch(source.substring(start + 1));
  final end = nextFunction == null
      ? source.length
      : start + 1 + nextFunction.start;
  return source.substring(start, end);
}

int _projectLockPosition(String body, String name) {
  final projectSourcePosition = body.indexOf('from public.projetos');
  expect(
    projectSourcePosition,
    greaterThanOrEqualTo(0),
    reason: 'public.$name deve consultar public.projetos.',
  );

  final projectLockPosition = body.indexOf('for update', projectSourcePosition);
  expect(
    projectLockPosition,
    greaterThanOrEqualTo(0),
    reason: 'public.$name deve bloquear public.projetos.',
  );
  return projectLockPosition;
}

List<String> _visualInsertPayloads(String source) {
  final payloads = <String>[];

  payloads.addAll(
    RegExp(
      r'''\.from\(\s*['"]ponto_inspecao_visual['"]\s*\)\s*\.insert\(\s*\{([\s\S]*?)\}\s*\)''',
      caseSensitive: false,
    ).allMatches(source).map((match) => match.group(1)!),
  );

  final variableInserts = RegExp(
    r'''\.from\(\s*['"]ponto_inspecao_visual['"]\s*\)\s*\.insert\(\s*([a-zA-Z_]\w*)\s*\)''',
    caseSensitive: false,
  ).allMatches(source);
  for (final insert in variableInserts) {
    final variable = insert.group(1)!;
    final declaration = RegExp(
      r'(?:final|var|const)\s+' +
          RegExp.escape(variable) +
          r'\s*=\s*\{([\s\S]*?)\};',
      caseSensitive: false,
    ).firstMatch(source);
    expect(
      declaration,
      isNotNull,
      reason: 'Payload $variable da inserção visual não foi resolvido.',
    );
    payloads.add(declaration!.group(1)!);
  }

  return payloads;
}

void main() {
  late String migration;
  late String rpcMigrations;
  late String projectRepository;
  late List<MapEntry<String, String>> visualSources;

  setUpAll(() {
    final migrationFile = File(_migrationPath);
    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
    final projectTeamAccessFile = File(_projectTeamAccessPath);
    expect(projectTeamAccessFile.existsSync(), isTrue);
    final homeProjectsFile = File(_homeProjectsPath);
    expect(homeProjectsFile.existsSync(), isTrue);
    final projectTeamFollowupFile = File(_projectTeamFollowupPath);
    expect(projectTeamFollowupFile.existsSync(), isTrue);
    rpcMigrations = [
      projectTeamAccessFile.readAsStringSync(),
      homeProjectsFile.readAsStringSync(),
      projectTeamFollowupFile.readAsStringSync(),
      migration,
    ].join('\n');
    projectRepository = File(_projectRepositoryPath).readAsStringSync();

    final visualRoot = Directory(_visualFeaturePath);
    expect(visualRoot.existsSync(), isTrue);
    visualSources = visualRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.dart'))
        .map((file) => MapEntry(file.path, file.readAsStringSync()))
        .toList();
  });

  test(
    'policies de inspeção visual atravessam ponto_inspecao_visual_geral',
    () {
      const policyNames = <String>[
        'remaining_visual_select',
        'remaining_visual_insert',
        'remaining_visual_update',
        'remaining_visual_delete',
      ];

      for (final name in policyNames) {
        final policy = _policyFor(migration, name, 'ponto_inspecao_visual');
        expect(
          policy,
          matches(
            RegExp(
              r'private\.can_(?:access|edit)_point_in_project\s*\(\s*'
              r'\(\s*select\s+vg\.id_ponto_geral\s+from\s+'
              r'public\.ponto_inspecao_visual_geral\s+vg\s+where\s+'
              r'vg\.id\s*=\s*ponto_inspecao_visual\.id_ponto_geral\s*\)\s*,'
              r'\s*ponto_inspecao_visual\.id_projeto\s*\)',
              caseSensitive: false,
            ),
          ),
          reason:
              'Policy $name deve resolver o id visual para o ponto raiz e '
              'autorizar esse ponto no projeto informado.',
        );
      }

      final helperCall = RegExp(
        r'private\.(?:can_access_point|can_edit_point)(?:_in_project)?\s*\(',
        caseSensitive: false,
      );

      const childPolicies = <MapEntry<String, String>>[
        MapEntry('remaining_visual_region_insert', 'ponto_inspecao_regiao'),
        MapEntry('remaining_visual_region_update', 'ponto_inspecao_regiao'),
        MapEntry('remaining_visual_region_delete', 'ponto_inspecao_regiao'),
        MapEntry(
          'remaining_visual_anomaly_insert',
          'ponto_inspecao_visual_anomalia',
        ),
        MapEntry(
          'remaining_visual_anomaly_update',
          'ponto_inspecao_visual_anomalia',
        ),
        MapEntry(
          'remaining_visual_anomaly_delete',
          'ponto_inspecao_visual_anomalia',
        ),
        MapEntry(
          'remaining_visual_gallery_insert',
          'ponto_inspecao_visual_galeria',
        ),
        MapEntry(
          'remaining_visual_gallery_update',
          'ponto_inspecao_visual_galeria',
        ),
        MapEntry(
          'remaining_visual_gallery_delete',
          'ponto_inspecao_visual_galeria',
        ),
      ];
      for (final child in childPolicies) {
        final policy = _policyFor(migration, child.key, child.value);
        for (final call in helperCall.allMatches(policy)) {
          expect(
            policy.substring(0, call.start),
            contains('public.ponto_inspecao_visual_geral'),
            reason:
                'Policy ${child.key} deve atravessar '
                'ponto_inspecao_visual_geral antes do helper.',
          );
        }
      }
    },
  );

  test(
    'policy de ponto_inspecao_visual não chama helper com id_ponto_geral direto',
    () {
      const policyNames = <String>[
        'remaining_visual_select',
        'remaining_visual_insert',
        'remaining_visual_update',
        'remaining_visual_delete',
      ];
      final directCall = RegExp(
        r'private\.can_access_point_in_project\s*\(\s*'
        r'id_ponto_geral\s*,\s*id_projeto\s*\)',
        caseSensitive: false,
      );

      for (final name in policyNames) {
        expect(
          _policyFor(migration, name, 'ponto_inspecao_visual'),
          isNot(matches(directCall)),
          reason: 'A policy $name não pode usar ids de tabelas diferentes.',
        );
      }
    },
  );

  test('toda policy UPDATE declara USING e WITH CHECK', () {
    final updatePolicies = _policyStatements(migration)
        .where(
          (statement) => RegExp(
            r'\bfor\s+update\b',
            caseSensitive: false,
          ).hasMatch(statement),
        )
        .toList();

    expect(updatePolicies, isNotEmpty);
    for (final policy in updatePolicies) {
      expect(policy, matches(RegExp(r'\busing\s*\(', caseSensitive: false)));
      expect(
        policy,
        matches(RegExp(r'\bwith\s+check\s*\(', caseSensitive: false)),
      );
    }
  });

  test('remaining RLS não recria policies já existentes em projetos', () {
    final projectPolicies = _policyStatements(migration)
        .where(
          (statement) => RegExp(
            r'\bon\s+public\.projetos\b',
            caseSensitive: false,
          ).hasMatch(statement),
        )
        .toList();

    expect(
      projectPolicies,
      isEmpty,
      reason:
          'A tabela public.projetos já é protegida pela migration '
          '20260903120000_harden_home_projects_rls.sql.',
    );
    expect(
      migration,
      contains('public.projetos is the 57th table in the overall rollout'),
      reason: 'O cabeçalho deve documentar por que projetos não é recriada.',
    );
    expect(
      _compactSql(migration),
      contains('grantselectontablepublic.projetostoauthenticated;'),
      reason: 'A leitura autenticada de projetos deve continuar disponível.',
    );
  });

  test('RPCs de projeto travam a linha antes do check de autorização', () {
    const authorizationChecks = <String, String>{
      'update_project': 'private.can_manage_project_member',
      'delete_project': 'private.is_active_company_admin',
      'save_region_with_contracts': 'private.can_manage_project_member',
      'invite_project_client': 'private.can_manage_project_member',
      'respond_to_project_client_invite': 'from public.usuarios',
      'respond_to_project_company_invite': 'from public.usuarios',
      'set_project_company_invite_status': 'private.can_manage_gestora_project',
      'set_project_member_status': 'from public.usuarios',
      'set_project_member_manager': 'from public.usuarios',
      'remove_project_client': 'private.can_manage_project_member',
      'transfer_project_management': 'private.is_active_company_admin',
    };

    for (final entry in authorizationChecks.entries) {
      final body = _functionBlock(rpcMigrations, entry.key).toLowerCase();
      final lockPosition = _projectLockPosition(body, entry.key);
      final authorizationPosition = body.indexOf(entry.value);

      expect(
        lockPosition,
        greaterThanOrEqualTo(0),
        reason: 'public.${entry.key} deve conter FOR UPDATE.',
      );
      expect(
        authorizationPosition,
        greaterThanOrEqualTo(0),
        reason: 'public.${entry.key} deve verificar autorização.',
      );
      expect(
        lockPosition,
        lessThan(authorizationPosition),
        reason:
            'public.${entry.key} deve bloquear o projeto antes do check '
            'de autorização.',
      );
    }
  });

  test('RPCs de convite travam projeto antes do convite', () {
    const functions = <String>[
      'respond_to_project_company_invite',
      'set_project_company_invite_status',
    ];

    for (final name in functions) {
      final body = _functionBlock(rpcMigrations, name).toLowerCase();
      final projectLockPosition = _projectLockPosition(body, name);
      final inviteSourcePosition = body.indexOf(
        'from public.projeto_empresas_colaboradoras',
        projectLockPosition,
      );
      final inviteLockPosition = body.indexOf(
        'for update',
        inviteSourcePosition,
      );

      expect(
        inviteSourcePosition,
        greaterThan(projectLockPosition),
        reason: 'public.$name deve reler o convite após bloquear o projeto.',
      );
      expect(
        inviteLockPosition,
        greaterThan(inviteSourcePosition),
        reason: 'public.$name deve bloquear o convite relido.',
      );
    }
  });

  test(
    'RPCs públicas listadas revogam acesso amplo e concedem só aos papéis certos',
    () {
      const signatures = <String, String>{
        'create_project': 'text,uuid,text,text,text,text',
        'update_project': 'uuid,text,text,text,text,text',
        'delete_project': 'uuid',
        'save_region_with_contracts': 'uuid,jsonb,jsonb',
        'invite_project_client': 'uuid,uuid',
        'respond_to_project_client_invite': 'uuid,uuid,boolean',
        'remove_project_client': 'uuid',
        'list_company_clients': 'uuid',
        'transfer_project_management': 'uuid,uuid',
      };

      final sql = _compactSql(migration);
      for (final entry in signatures.entries) {
        final signature = entry.value;
        final revoke = RegExp(
          r'revokeallonfunctionpublic\.' +
              RegExp.escape(entry.key) +
              r'\(' +
              RegExp.escape(signature) +
              r'\)from([^;]+);',
          caseSensitive: false,
        ).firstMatch(sql);
        expect(
          revoke,
          isNotNull,
          reason: 'RPC ${entry.key} precisa de REVOKE explícito.',
        );
        final revokedRoles = revoke!
            .group(1)!
            .split(',')
            .map((role) => role.trim().toLowerCase())
            .toSet();
        expect(revokedRoles, containsAll(<String>{'public', 'anon'}));

        final grant = RegExp(
          r'grantexecuteonfunctionpublic\.' +
              RegExp.escape(entry.key) +
              r'\(' +
              RegExp.escape(signature) +
              r'\)to([^;]+);',
          caseSensitive: false,
        ).firstMatch(sql);
        expect(
          grant,
          isNotNull,
          reason: 'RPC ${entry.key} precisa de GRANT explícito.',
        );
        final grantedRoles = grant!
            .group(1)!
            .split(',')
            .map((role) => role.trim().toLowerCase())
            .toSet();
        expect(grantedRoles, <String>{'authenticated', 'service_role'});
      }
    },
  );

  test('RPCs de projeto aceitam somente caminhos de imagem validados', () {
    final createProject = _functionBlock(migration, 'create_project');
    final updateProject = _functionBlock(migration, 'update_project');
    final helper = RegExp(
      r'create\s+or\s+replace\s+function\s+'
      r'private\.canonical_project_image_url\b[\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(_stripSqlComments(migration));

    expect(helper, isNotNull);
    final helperSql = helper!.group(0)!;
    expect(helperSql, contains("p_directory not in ('capas', 'clientes')"));
    expect(helperSql, contains("o.bucket_id = 'projetos'"));
    expect(helperSql, contains('o.name = v_path'));
    final compact = _compactSql(migration);
    expect(
      compact,
      contains(
        'revokeallonfunctionprivate.canonical_project_image_url'
        '(text,uuid,text)frompublic,anon,authenticated;',
      ),
    );
    expect(
      compact,
      isNot(
        contains(
          'grantexecuteonfunctionprivate.canonical_project_image_url'
          '(text,uuid,text)toauthenticated',
        ),
      ),
    );
    expect(
      createProject,
      contains("canonical_project_image_url(p_image_url, v_actor, 'capas')"),
    );
    expect(
      createProject,
      contains(
        "canonical_project_image_url(p_new_client_image_url, v_actor, 'clientes')",
      ),
    );
    expect(
      updateProject,
      contains("canonical_project_image_url(p_image_url, v_actor, 'capas')"),
    );
    expect(projectRepository, contains("'p_image_url': projectImage?.path"));
    expect(
      projectRepository,
      contains("'p_new_client_image_url': clientImage?.path"),
    );
    expect(projectRepository, contains("'p_image_url': uploadedImage?.path"));
  });

  test('todo registro visual envia projeto, estrutura e ponto geral', () {
    final registrations = <String, String>{};
    for (final source in visualSources) {
      for (final payload in _visualInsertPayloads(source.value)) {
        registrations[source.key] =
            '${registrations[source.key] ?? ''}\n$payload';
      }
    }

    expect(
      registrations,
      isNotEmpty,
      reason: 'Nenhum consumidor local insere em ponto_inspecao_visual.',
    );
    for (final entry in registrations.entries) {
      for (final field in <String>[
        'id_projeto',
        'id_estrutura',
        'id_ponto_geral',
      ]) {
        expect(
          entry.value,
          matches(
            RegExp(
              r'''['"]''' + RegExp.escape(field) + r'''['"]\s*:''',
              caseSensitive: false,
            ),
          ),
          reason:
              '${entry.key} deve enviar $field ao registrar inspeção visual.',
        );
      }
    }
  });
}
