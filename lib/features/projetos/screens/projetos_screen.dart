import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';

class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    //Escuta a lista filtrada (Reage automaticamente aos filtros e busca!)
    final projetosAsync = ref.watch(filteredProjectsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // O FAB e o BottomBar ficam na MainScreen (ShellRoute)
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // HEADER
          _buildHeader(context, ref, topPadding),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(
                    height: 40,
                  ), // Espaço para a search bar que flutua

                  _buildFilterRow(ref),

                  const SizedBox(height: 16),

                  // LISTA DE CARDS
                  Expanded(
                    child: projetosAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                      error: (err, stack) =>
                          Center(child: Text('Erro ao carregar: $err')),
                      data: (lista) {
                        if (lista.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhum projeto encontrado',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                // Esse espaço extra ajuda a compensar visualmente o FAB que flutua embaixo
                                const SizedBox(height: 80),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: lista.length,
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 100,
                          ), // Espaço pro FAB
                          itemBuilder: (context, index) {
                            final projeto = lista[index];
                            return InkWell(
                              // Envia o ID para a tela de detalhes
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

  Widget _buildHeader(BuildContext context, WidgetRef ref, double topPadding) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140 + topPadding,
          padding: EdgeInsets.only(top: topPadding + 10, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage: AssetImage('assets/images/user.png'),
                  ),
                  const Text(
                    'Projetos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push('/notificacoes'),
                  ),
                  // BOTÃO DE LOGOUT PROVISÓRIO
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Sair (Teste)',
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      ref.invalidate(currentUserProvider);
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Acompanhe o progresso das suas iniciativas',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'Lato',
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -26,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CustomSearchBar(
              hintText: 'Buscar projetos ou clientes...',
              onChanged: (val) {
                // Atualiza o estado da busca no Riverpod
                ref.read(searchQueryProvider.notifier).state = val;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(WidgetRef ref) {
    final statusAtual = ref.watch(filtroStatusProvider);
    final isRecente = ref.watch(filtroRecentesProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<String>(
          initialValue: statusAtual,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (val) {
            ref.read(filtroStatusProvider.notifier).state = val;
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'Todos',
              child: Text(
                'Todos',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'Em andamento',
              child: Text(
                'Em andamento',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuItem(
              value: 'Concluído',
              child: Text(
                'Concluído',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusAtual,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textDark,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            ref.read(filtroRecentesProvider.notifier).state = !isRecente;
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  isRecente ? 'Recentes' : 'Antigos',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isRecente ? Icons.arrow_downward : Icons.arrow_upward,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
