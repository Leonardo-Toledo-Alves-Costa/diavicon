import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../../estrutura/widgets/structure_card.dart';
import '../../estrutura/widgets/incluir_estrutura_body.dart';
import '../../estrutura/providers/estrutura_provider.dart';
import '../models/projeto_model.dart';

class StructuresSection extends ConsumerWidget {
  final ProjetoModel projeto;
  final String projetoId;
  
  const StructuresSection({
    super.key, 
    required this.projeto, 
    required this.projetoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estruturasAsync = ref.watch(projetoEstruturasProvider(projetoId));

    return Column(
      children: [
        Row(
          children: [
            const Text(
              'Estruturas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: CompactSearchBar()),
            const SizedBox(width: 6),
            CompactButton(
              text: 'Incluir',
              onPressed: () {
                showDiaviconModal(
                  context: context,
                  title: 'Incluir Estrutura',
                  height: MediaQuery.of(context).size.height * 0.80,
                  isScrollable: false,
                  margin: const EdgeInsets.fromLTRB(18, 150, 18, 0),
                  centerTitle: true,
                  body: IncluirEstruturaBody(
                    clienteNome: projeto.clienteNome ?? 'Cliente não definido',
                    empresaNome: projeto.empresaNome,
                    projetoId: projetoId,
                    empresaLogoUrl: projeto.empresaFotoUrl,


                    
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: estruturasAsync.when(
            data: (estruturas) {
              if (estruturas.isEmpty) {
                return const Center(
                  child: CustomEmptyState(
                    text: 'Projeto sem estruturas incluídas',
                  ),
                );
              }
              return SizedBox(
                height: 0,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: estruturas.length,
                  itemBuilder: (context, index) {
                    return StructureCard(
                      estrutura: estruturas[index],
                      projetoId: projetoId,
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(child: Text('Erro: $err', style: const TextStyle(color: AppColors.error))),
          ),
        ),
      ],
    );
  }
}