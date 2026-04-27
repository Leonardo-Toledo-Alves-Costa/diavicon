import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';

class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    // 1. Escuta a lista filtrada (Cérebro da busca)
    final projetosAsync = ref.watch(filteredProjectsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // O FAB e o BottomBar ficam na MainScreen (ShellRoute)
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // 2. HEADER CUSTOMIZADO (Laranja com busca)
          _buildHeader(context, ref, topPadding),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40), // Espaço para a search bar que flutua
                  
                  // 3. FILTROS (Dropdown e Sort)
                  _buildFilterRow(),
                  
                  const SizedBox(height: 16),
                  
                  // 4. LISTA DE CARDS
                  Expanded(
                    child: projetosAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                      error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
                      data: (lista) {
                        if (lista.isEmpty) {
                          return const Center(
                            child: Text('Nenhum projeto encontrado.'),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: lista.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 100), // Espaço pro FAB global
                          itemBuilder: (context, index) {
                            final projeto = lista[index];
                            return InkWell(
                              // Envia o ID para a tela de detalhes
                              onTap: () => context.push('/projetos/detalhes', extra: projeto.id),
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

  // --- MÉTODOS AUXILIARES ---

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
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () {
                      // Ação de notificações
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Acompanhe o progresso das suas iniciativas',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Lato'),
              ),
            ],
          ),
        ),
        
        // Search Bar posicionada entre o Header e o Body
        Positioned(
          bottom: -24,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
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

  Widget _buildFilterRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          value: 'Todos',
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
          items: const [
            DropdownMenuItem(
              value: 'Todos', 
              child: Text(
                'Todos', 
                style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)
              ),
            ),
          ],
          onChanged: (val) {
            // Futura lógica de filtro por status
          },
        ),
        const Icon(Icons.swap_vert, color: AppColors.primary),
      ],
    );
  }
}