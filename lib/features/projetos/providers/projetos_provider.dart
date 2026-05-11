import 'package:diavicon/features/projetos/repositories/project_repository.dart';
import 'package:diavicon/features/projetos/models/projeto_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

final projetoRepositoryProvider = Provider((ref) => ProjectRepository(Supabase.instance.client));
/// Provider da LISTA BRUTA 
/// Ele observa o currentUserProvider para buscar apenas os projetos
/// que o usuário tem permissão para ver
final projectsListProvider = FutureProvider<List<ProjetoModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  
  // Se não tem usuário logado, retorna lista vazia
  if (user == null) return [];

  final repo = ref.read(projetoRepositoryProvider);
  return await repo.fetchUserProjects(user.id);
});

/// Provider da BUSCA
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider da LISTA FILTRADA
/// Faz o filtro em memória, sem precisar bater no Supabase toda hora
final filteredProjectsProvider = Provider<AsyncValue<List<ProjetoModel>>>((ref) {
  final projectsAsync = ref.watch(projectsListProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return projectsAsync.whenData((lista) {
    if (query.isEmpty) return lista;
    
    return lista.where((p) {
      final matchesNome = p.nome.toLowerCase().contains(query);
      final matchesDesc = p.descricao?.toLowerCase().contains(query) ?? false;
      return matchesNome || matchesDesc;
    }).toList();
  });
});

/// Provider do DETALHE (Usado na ProjectDetailScreen)
/// O .family permite passar o ID do projeto por parâmetro.
final projectDetailProvider = FutureProvider.family<ProjetoModel, String>((ref, id) async {
  final repo = ref.read(projetoRepositoryProvider);
  return await repo.getProjectById(id);
});