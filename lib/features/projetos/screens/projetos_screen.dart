import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/status_badge.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';

class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;

    final projetosAsync = ref.watch(projetosProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // No build da ProjetosScreen, substitua o início do ListView:
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                // Altura reduzida para ocupar menos espaço
                height: 130 + topPadding,
                padding: EdgeInsets.only(
                  top: topPadding + 8,
                  left: 24,
                  right: 24,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const CircleAvatar(
                          radius: 18, // Foto de perfil um pouco menor
                          backgroundImage: AssetImage('assets/images/user.png'),
                        ),
                        const Text(
                          'Projetos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const Text(
                      'Acompanhe o progresso das suas iniciativas',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // A barra de busca agora fica mais próxima do conteúdo
              Positioned(
                bottom: -22,
                left: 24,
                right: 24,
                child: Container(
                  height: 44, // Barra de busca um pouco mais fina
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CustomSearchBar(
                    hintText: 'Buscar projetos ou clientes...',
                    onChanged: (val) {},
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: 'Todos',
                      underline: const SizedBox(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: const [
                        DropdownMenuItem(
                          value: 'Todos',
                          child: Text('Todos', style: TextStyle(fontSize: 16)),
                        ),
                        DropdownMenuItem(
                          value: 'Ativos',
                          child: Text('Ativos', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                      onChanged: (val) {},
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.swap_vert,
                        color: AppColors.primary,
                      ),
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                projetosAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  error: (erro, stack) => Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Text(
                        'Erro ao carregar projetos:\n$erro',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),

                  data: (listaProjetos) {
                    if (listaProjetos.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Center(
                          child: Text(
                            'Você ainda não possui projetos.',
                            style: TextStyle(
                              color: AppColors.hintText,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: listaProjetos.map((projeto) {
                        return ProjectCard(
                          title: projeto.nome,
                          progress: projeto.progresso,
                          status: projeto.statusBadge,
                          priority: projeto.prioridadeNome,
                          imageUrl: projeto.imageUrl,
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
