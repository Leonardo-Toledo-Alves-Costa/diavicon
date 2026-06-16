import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';

// 🔥 Nossos novos componentes limpos!
import '../widgets/projetos_header.dart';
import '../widgets/projetos_filter_row.dart';

class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    // Escuta a lista filtrada (Reage automaticamente aos filtros e busca!)
    final projetosAsync = ref.watch(filteredProjectsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // 🔥 HEADER EXTRAÍDO
          ProjetosHeader(topPadding: topPadding),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40), // Espaço para a search bar que flutua

                  // 🔥 FILTROS EXTRAÍDOS
                  const ProjetosFilterRow(),

                  const SizedBox(height: 16),

                  // LISTA DE CARDS
                  Expanded(
                    child: projetosAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      error: (err, stack) =>
                          Center(child: Text('Erro ao carregar: $err')),
                      data: (lista) {
                        // ESTADO VAZIO
                        if (lista.isEmpty) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomEmptyState(text: 'Nenhum projeto encontrado'),
                              SizedBox(height: 80), // Compensação visual do FAB
                            ],
                          );
                        }

                        // ESTADO PREENCHIDO
                        return ListView.builder(
                          itemCount: lista.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 100), 
                          itemBuilder: (context, index) {
                            final projeto = lista[index];
                            return InkWell(
                              onTap: () => context.push(
                                '/projetos/detalhes',
                                extra: projeto.id,
                              ),
                              child: ProjectCard(
                                title: projeto.nome,
                                progress: projeto.progresso,
                                status: projeto.statusBadge,
                                priority: projeto.prioridadeNome,
                                imageUrl: projeto.imageUrl,
                                teamAvatars: projeto.equipeFotos,
                                empresaFotoUrl: projeto.empresaFotoUrl,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}