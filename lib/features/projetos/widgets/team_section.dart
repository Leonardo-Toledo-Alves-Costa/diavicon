import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../equipe/widgets/edit_team_body.dart';
import '../../equipe/widgets/team_member_item.dart';
import '../../equipe/providers/equipe_provider.dart';

class TeamSection extends ConsumerWidget {
  final String projetoId;
  
  const TeamSection({
    super.key, 
    required this.projetoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colaboradoresAsync = ref.watch(
      colaboradoresAtivosProjetoProvider(projetoId),
    );
    
    // 🔥 ESCUTANDO O "SEGURANÇA": Esse cara dita se o botão de '+' aparece ou não!
    final canEditAsync = ref.watch(permissaoEdicaoEquipeProvider(projetoId));
    final bool canEdit = canEditAsync.value ?? false;

    return colaboradoresAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, stack) => const Text(
        'Erro ao carregar equipe',
        style: TextStyle(color: Colors.red),
      ),
      data: (listaColaboradores) {
        
        // ESTADO VAZIO DA EQUIPE
        if (listaColaboradores.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomEmptyState(
                text: 'Equipe não definida',
              ),
              const SizedBox(height: 12),
              
              // 🔥 PROTEÇÃO AQUI: Só mostra o botão se tiver permissão
              if (canEdit)
                GestureDetector(
                  onTap: () {
                    showDiaviconModal(
                      context: context,
                      title: 'Edite a equipe',
                      body: EditTeamBody(projetoId: projetoId),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Adicionar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          );
        }

        // COM COLABORADORES NA EQUIPE
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...listaColaboradores.map((item) {
                final usuario = item['usuario'] as Map<String, dynamic>;
                return TeamMemberItem(
                  name: usuario['nome'] ?? 'Sem nome',
                  role: usuario['cargo'] ?? 'Colaborador',
                  imagePath: usuario['foto_url'] ?? 'assets/images/user.png',
                );
              }),

              // 🔥 PROTEÇÃO AQUI: O botão redondo de "+" só aparece para Admin/Gestor
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 0, right: 0),
                  child: GestureDetector(
                    onTap: () {
                      showDiaviconModal(
                        context: context,
                        title: 'Edite a equipe',
                        body: EditTeamBody(projetoId: projetoId),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}