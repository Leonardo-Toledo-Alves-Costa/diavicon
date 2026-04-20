import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart'; // Usando o seu widget padrão
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';

class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final projetosAsync = ref.watch(projetosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Cinza de fundo leve
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. HEADER COMPACTO E LARANJA OFICIAL
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 140 + topPadding,
                padding: EdgeInsets.only(top: topPadding + 10, left: 24, right: 24),
                decoration: const BoxDecoration(
                  color: AppColors.primary, // #D99100 oficial
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
                          onPressed: () {},
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
              
              // 2. SEARCH BAR PADRONIZADA
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
                      // Lógica de busca
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40), 
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // FILTROS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: 'Todos',
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                      items: const [
                        DropdownMenuItem(value: 'Todos', child: Text('Todos', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) {},
                    ),
                    const Icon(Icons.swap_vert, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 16),

                // LISTA DE PROJETOS COM NAVEGAÇÃO
                projetosAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (erro, stack) => Text('Erro: $erro', style: const TextStyle(color: Colors.red)),
                  data: (listaProjetos) {
                    return Column(
                      children: listaProjetos.map((projeto) {
                        return InkWell(
                          // NAVEGAÇÃO PARA A DETAIL SCREEN
                          onTap: () => context.push('/projetos/detalhes', extra: projeto),
                          child: ProjectCard(
                            title: projeto.nome,
                            progress: projeto.progresso,
                            status: projeto.statusBadge,
                            priority: projeto.prioridadeNome,
                            imageUrl: projeto.imageUrl, 
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}