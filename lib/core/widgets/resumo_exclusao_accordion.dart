import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Sanfona "O que mais será excluído junto" pros diálogos de exclusão de
/// projeto/estrutura/elemento — fica fechada por padrão (a lista pode ficar
/// grande, ex: dezenas de pontos de ensaio) e, ao abrir, mostra os itens
/// agrupados por categoria numa área com altura fixa e rolagem própria.
class ResumoExclusaoAccordion extends StatelessWidget {
  /// Categoria (ex: "Elementos estruturais", "Pontos de Ultrassom") -> nomes
  /// dos itens dessa categoria que serão excluídos junto.
  final Map<String, List<String>> itensPorCategoria;

  const ResumoExclusaoAccordion({super.key, required this.itensPorCategoria});

  int get _total => itensPorCategoria.values.fold(0, (soma, itens) => soma + itens.length);

  @override
  Widget build(BuildContext context) {
    if (_total == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Nada mais será excluído junto.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        iconColor: AppColors.error,
        collapsedIconColor: AppColors.error,
        title: Text(
          'O que mais será excluído junto ($_total)',
          textAlign: TextAlign.left,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
        ),
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entrada in itensPorCategoria.entries)
                      if (entrada.value.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            '${entrada.key} (${entrada.value.length})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E3E3D)),
                          ),
                        ),
                        for (final item in entrada.value)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 3),
                            child: Text(
                              '•  $item',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                      ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
