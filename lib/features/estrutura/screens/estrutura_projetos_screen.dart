import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../../projetos/widgets/project_card.dart';
import '../models/estrutura_model.dart';
import '../providers/estrutura_provider.dart';

/// Lista os projetos em que a estrutura está sendo trabalhada (relação N:N
/// via `projeto_estruturas`) — acessada a partir do preview da estrutura na
/// aba "Estruturas". Tocar num projeto abre ele normalmente.
class EstruturaProjetosScreen extends ConsumerWidget {
  final EstruturaModel estrutura;

  const EstruturaProjetosScreen({super.key, required this.estrutura});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projetosAsync = ref.watch(projetosPorEstruturaProvider(estrutura.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Projetos vinculados', style: TextStyle(fontSize: 11, color: Colors.white70)),
            Text(
              estrutura.nome ?? 'Sem nome',
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: projetosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Erro ao carregar projetos: $err')),
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(child: CustomEmptyState(text: 'Nenhum projeto vinculado a esta estrutura'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final projeto = lista[index];
              return InkWell(
                onTap: () => context.push('/projetos/detalhes', extra: projeto.id),
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
    );
  }
}
