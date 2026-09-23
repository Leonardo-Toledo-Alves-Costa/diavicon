import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/estruturas_dropdown_provider.dart';
import '../screens/estruturas_tab_screen.dart';

class EstruturasFilterRow extends ConsumerWidget {
  const EstruturasFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conjuntoFiltroId = ref.watch(estruturaConjuntoFiltroProvider);
    final somenteMonitoradas = ref.watch(estruturaSomenteMonitoradasProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ref.watch(conjuntosEstruturaisProvider).when(
          loading: () => const Text('Carregando...', style: TextStyle(color: AppColors.hintText, fontSize: 14)),
          error: (e, _) => const Text('Erro', style: TextStyle(color: Colors.red, fontSize: 14)),
          data: (conjuntos) {
            String nomeSelecionado = 'Todos';
            if (conjuntoFiltroId != null) {
              final selecionado = conjuntos.firstWhere(
                (c) => c['id'].toString() == conjuntoFiltroId,
                orElse: () => {'nome': 'Todos'},
              );
              nomeSelecionado = selecionado['nome'].toString();
            }

            return PopupMenuButton<String?>(
              initialValue: conjuntoFiltroId,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                ref.read(estruturaConjuntoFiltroProvider.notifier).state = (val == 'TODOS') ? null : val;
              },
              itemBuilder: (context) {
                final List<PopupMenuEntry<String?>> items = [
                  const PopupMenuItem<String?>(
                    value: 'TODOS',
                    child: Text('Todos', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                  ),
                ];

                items.addAll(
                  conjuntos.map((c) => PopupMenuItem<String?>(
                    value: c['id'].toString(),
                    child: Text(c['nome'].toString(), style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
                  )),
                );
                return items;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nomeSelecionado,
                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 14), // Padrão igual ao ProjetosFilterRow
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: AppColors.textDark, size: 20),
                  ],
                ),
              ),
            );
          },
        ),

        // Alterna entre todas as estruturas e somente as monitoradas. O
        // rotulo mostra o modo ATIVO, nao o destino do toque.
        InkWell(
          onTap: () => ref.read(estruturaSomenteMonitoradasProvider.notifier).state = !somenteMonitoradas,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  somenteMonitoradas ? 'Monitoradas' : 'Todas',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 4),
                Icon(
                  somenteMonitoradas ? Icons.monitor_heart_outlined : Icons.format_list_bulleted,
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