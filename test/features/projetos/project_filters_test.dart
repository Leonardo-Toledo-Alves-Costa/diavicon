import 'package:diavicon/core/models/badge_status.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:diavicon/features/projetos/utils/project_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final oldest = _project(
    id: '1',
    name: 'Ponte Central',
    company: 'Asimov',
    status: BadgeStatus.emAndamento,
    createdAt: DateTime.utc(2025),
    client: 'Prefeitura',
  );
  final newest = _project(
    id: '2',
    name: 'Galpão Norte',
    company: 'Diavicon',
    status: BadgeStatus.concluido,
    createdAt: DateTime.utc(2026),
  );
  final cancelled = _project(
    id: '3',
    name: 'Viaduto Sul',
    company: 'Cliente Exemplo',
    status: BadgeStatus.cancelado,
    createdAt: DateTime.utc(2024),
  );

  test('filtra por nome ou empresa ignorando caixa e espaços', () {
    expect(
      filterProjects(
        [oldest, newest, cancelled],
        searchQuery: '  DIAVICON ',
        statusFilter: 'Todos',
        newestFirst: true,
      ).map((project) => project.id),
      ['2'],
    );

    expect(
      filterProjects(
        [oldest, newest, cancelled],
        searchQuery: 'ponte',
        statusFilter: 'Todos',
        newestFirst: true,
      ).map((project) => project.id),
      ['1'],
    );

    expect(
      filterProjects(
        [oldest, newest, cancelled],
        searchQuery: 'prefeitura',
        statusFilter: 'Todos',
        newestFirst: true,
      ).map((project) => project.id),
      ['1'],
    );
  });

  test('aplica status e ordenação sem alterar a lista original', () {
    final original = [oldest, newest, cancelled];

    final completed = filterProjects(
      original,
      searchQuery: '',
      statusFilter: 'Concluído',
      newestFirst: true,
    );
    final chronological = filterProjects(
      original,
      searchQuery: '',
      statusFilter: 'Todos',
      newestFirst: false,
    );

    expect(completed.map((project) => project.id), ['2']);
    expect(chronological.map((project) => project.id), ['3', '1', '2']);
    expect(original.map((project) => project.id), ['1', '2', '3']);
  });

  test('reconhece o filtro de cancelados', () {
    final result = filterProjects(
      [oldest, newest, cancelled],
      searchQuery: '',
      statusFilter: 'Cancelado',
      newestFirst: true,
    );

    expect(result.single.id, '3');
  });
}

ProjetoModel _project({
  required String id,
  required String name,
  required String company,
  required BadgeStatus status,
  required DateTime createdAt,
  String? client,
}) {
  return ProjetoModel(
    id: id,
    nome: name,
    empresaNome: company,
    statusBadge: status,
    criadoEm: createdAt,
    clienteNome: client,
  );
}
