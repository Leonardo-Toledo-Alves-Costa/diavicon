import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/projetos_provider.dart';

class ProjetosFilterRow extends ConsumerWidget {
  const ProjetosFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          onOpened: () => FocusManager.instance.primaryFocus?.unfocus(),
          onSelected: (val) {
            FocusManager.instance.primaryFocus?.unfocus();
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
            FocusManager.instance.primaryFocus?.unfocus();
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