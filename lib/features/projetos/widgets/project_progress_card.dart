import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../ensaios/ensaios_geral/progresso/progresso_ensaios.dart';

/// Progresso do projeto: média ponderada das estruturas pelos pontos de
/// ensaio contratados para a empresa (ver progresso_ensaios.dart).
class ProjectProgressCard extends ConsumerWidget {
  final String projetoId;

  const ProjectProgressCard({
    super.key,
    required this.projetoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(progressoProjetoProvider(projetoId));
    final progresso = async.value?.fracao;
    final carregando = async.isLoading && !async.hasValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Fundo laranja bem claro
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progresso',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                carregando ? '' : textoProgresso(progresso),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: carregando ? null : (progresso ?? 0),
              backgroundColor: const Color(0xFFE0E0E0),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
          if (!carregando && progresso == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Sem ensaios contratados para a sua empresa neste projeto.',
              style: TextStyle(fontSize: 12, color: AppColors.hintText),
            ),
          ],
        ],
      ),
    );
  }
}
