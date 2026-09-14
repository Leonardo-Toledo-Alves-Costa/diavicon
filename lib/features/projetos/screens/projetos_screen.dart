import 'package:diavicon/features/app_shell/widgets/perfil_drawer.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../widgets/project_card.dart';
import '../providers/projetos_provider.dart';
import '../widgets/projetos_header.dart';
import '../widgets/projetos_filter_row.dart';

class ProjetosScreen extends ConsumerStatefulWidget {
  const ProjetosScreen({super.key});

  @override
  ConsumerState<ProjetosScreen> createState() => _ProjetosScreenState();
}

class _ProjetosScreenState extends ConsumerState<ProjetosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final projetosAsync = ref.watch(filteredProjectsProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF5F5F5),
          resizeToAvoidBottomInset: false,
          drawer: const PerfilDrawer(),
          body: Column(
            children: [
              ProjetosHeader(
                topPadding: topPadding,
                onOpenDrawer: () {
                  FocusManager.instance.primaryFocus?.unfocus();
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
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 100,
                              ),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemBuilder: (context, index) {
                                final projeto = lista[index];
                                return InkWell(
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    context.pushNamed(
                                      AppRouteNames.projectDetail,
                                      pathParameters: <String, String>{
                                        AppPaths.projectIdParameter: projeto.id,
                                      },
                                    );
                                  },
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
        ),
      ),
    );
  }
}
