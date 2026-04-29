import 'package:diavicon/features/empresa/repositories/project_repository.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final projectRepositoryProvider = Provider((ref) => ProjectRepository(Supabase.instance.client));

// Provider da LISTA
final projectsListProvider = FutureProvider<List<ProjetoModel>>((ref) {
  return ref.watch(projectRepositoryProvider).getProjects();
});

// Provider do DETALHE (Usado na ProjectDetailScreen)
final projectDetailProvider = FutureProvider.family<ProjetoModel, String>((ref, id) {
  return ref.watch(projectRepositoryProvider).getProjectById(id);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

// filtro automático da lista
final filteredProjectsProvider = Provider<AsyncValue<List<ProjetoModel>>>((ref) {
  final projectsAsync = ref.watch(projectsListProvider); //lista original do banco
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return projectsAsync.whenData((lista) {
    if (query.isEmpty) return lista;
    // Filtra pelo nome do projeto
    return lista.where((p) => p.nome.toLowerCase().contains(query)).toList();
  });
  });