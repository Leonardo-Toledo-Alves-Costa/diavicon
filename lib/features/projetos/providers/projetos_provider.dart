import 'package:diavicon/core/providers/supabase_provider.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:diavicon/features/projetos/repositories/project_repository.dart';
import 'package:diavicon/features/projetos/utils/project_filters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(supabaseClientProvider));
});

final searchQueryProvider = StateProvider<String>((ref) => '');
final filtroStatusProvider = StateProvider<String>((ref) => 'Todos');
final filtroRecentesProvider = StateProvider<bool>((ref) => true);

/// Consulta remota. Alterar filtros visuais não refaz chamadas ao Supabase.
final projectsProvider = FutureProvider.autoDispose<List<ProjetoModel>>((ref) {
  return ref.watch(projectRepositoryProvider).fetchVisibleProjects();
});

/// Projeção local usada pela tela de projetos.
final filteredProjectsProvider =
    Provider.autoDispose<AsyncValue<List<ProjetoModel>>>((ref) {
      final projects = ref.watch(projectsProvider);
      final searchQuery = ref.watch(searchQueryProvider);
      final statusFilter = ref.watch(filtroStatusProvider);
      final newestFirst = ref.watch(filtroRecentesProvider);

      return projects.whenData(
        (items) => filterProjects(
          items,
          searchQuery: searchQuery,
          statusFilter: statusFilter,
          newestFirst: newestFirst,
        ),
      );
    });

final loggedUserCompanyIdProvider = FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(projectRepositoryProvider).fetchCurrentUserCompanyId();
});

final projectDetailProvider = FutureProvider.autoDispose
    .family<ProjetoModel, String>((ref, projectId) {
      return ref.watch(projectRepositoryProvider).fetchProjectById(projectId);
    });
