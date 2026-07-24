import 'package:diavicon/features/home/screens/perfil_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';
import '../widgets/projetos_header.dart';
import '../widgets/projetos_filter_row.dart';
// 🔥 Importe a gaveta que acabou de criar

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
class ProjetosScreen extends ConsumerWidget {
  const ProjetosScreen({super.key});
  

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final projetosAsync = ref.watch(filteredProjectsProvider);

    return Scaffold(
      key: _scaffoldKey,

      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      // 🔥 AQUI: Conecta a gaveta do lado direito!
      drawer: const PerfilDrawer(),
      body: Column(
        children: [
          ProjetosHeader(
            topPadding: topPadding,
            onOpenDrawer: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const ProjetosFilterRow(),
                  const SizedBox(height: 16),

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
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomEmptyState(
                                text: 'Nenhum projeto encontrado',
                              ),
                              SizedBox(height: 80),
                            ],
                          );
                        }

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
