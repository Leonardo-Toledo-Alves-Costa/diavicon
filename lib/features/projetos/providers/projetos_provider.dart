import 'package:diavicon/core/widgets/status_badge.dart';
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
  
  if (user == null) return [];

  final repo = ref.read(projetoRepositoryProvider);
  return await repo.fetchUserProjects(user.id);
});

// ESTADOS DOS FILTROS DA TELA
/// Provider da BUSCA (Texto)
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider do STATUS (Dropdown)
final filtroStatusProvider = StateProvider<String>((ref) => 'Todos');

/// Provider da ORDENAÇÃO (Botão de Setas) - true = Recentes, false = Antigos
final filtroRecentesProvider = StateProvider<bool>((ref) => true);


// LISTA FINAL PROCESSADA 
/// Faz o filtro em memória, sem precisar bater no Supabase toda hora
final filteredProjectsProvider = Provider<AsyncValue<List<ProjetoModel>>>((ref) {
  final projectsAsync = ref.watch(projectsListProvider);
  
  // Escuta os 3 filtros
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final statusString = ref.watch(filtroStatusProvider);
  final isRecente = ref.watch(filtroRecentesProvider);

  return projectsAsync.whenData((listaBruta) {
    var lista = List<ProjetoModel>.from(listaBruta);

    //  Filtro de Busca (Texto)
    if (query.isNotEmpty) {
      lista = lista.where((p) {
        final matchesNome = p.nome.toLowerCase().contains(query);
        final matchesCli = p.clienteNome?.toLowerCase().contains(query) ?? false;
        return matchesNome || matchesCli;
      }).toList();
    }

    // Filtro de Status (Dropdown -> Enum)
    if (statusString != 'Todos') {
      lista = lista.where((p) {
        // Converte o texto do Dropdown para o seu Enum BadgeStatus
        BadgeStatus statusAlvo;
        if (statusString == 'Em andamento') {
          statusAlvo = BadgeStatus.emAndamento;
        } else if (statusString == 'Concluído') {
          statusAlvo = BadgeStatus.concluido;
        } else {
          statusAlvo = BadgeStatus.cancelado;
        }
        
        return p.statusBadge == statusAlvo;
      }).toList();
    }

    // Ordenação por Data
    lista.sort((a, b) {
      if (isRecente) {
        return b.criadoEm.compareTo(a.criadoEm); // Mais novos no topo
      } else {
        return a.criadoEm.compareTo(b.criadoEm); // Mais antigos no topo
      }
    });

    return lista;
  });
});


/// Provider do DETALHE (Usado na ProjectDetailScreen)
/// O .family permite passar o ID do projeto por parâmetro
final projectDetailProvider = FutureProvider.family<ProjetoModel, String>((ref, id) async {
  final repo = ref.read(projetoRepositoryProvider);
  return await repo.getProjectById(id);
});