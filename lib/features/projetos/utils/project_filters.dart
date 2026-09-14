import 'package:diavicon/core/models/badge_status.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';

List<ProjetoModel> filterProjects(
  Iterable<ProjetoModel> projects, {
  required String searchQuery,
  required String statusFilter,
  required bool newestFirst,
}) {
  final normalizedQuery = searchQuery.trim().toLowerCase();

  final filtered = projects.where((project) {
    final matchesSearch =
        normalizedQuery.isEmpty ||
        project.nome.toLowerCase().contains(normalizedQuery) ||
        project.empresaNome.toLowerCase().contains(normalizedQuery) ||
        (project.clienteNome?.toLowerCase().contains(normalizedQuery) ?? false);

    final matchesStatus = switch (statusFilter) {
      'Em andamento' => project.statusBadge == BadgeStatus.emAndamento,
      'Concluído' ||
      'Concluido' => project.statusBadge == BadgeStatus.concluido,
      'Cancelado' => project.statusBadge == BadgeStatus.cancelado,
      _ => true,
    };

    return matchesSearch && matchesStatus;
  }).toList();

  filtered.sort((a, b) {
    final comparison = a.criadoEm.compareTo(b.criadoEm);
    return newestFirst ? -comparison : comparison;
  });

  return filtered;
}
