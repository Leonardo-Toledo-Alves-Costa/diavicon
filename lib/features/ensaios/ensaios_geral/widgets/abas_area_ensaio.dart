import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/area_ensaio.dart';

/// Abas Concreto · Metálicas · Laboratório usadas nas listas de ensaio
/// ("Adicionar Ensaio" e a tela "Ensaios" da estrutura).
class AbasAreaEnsaio extends StatelessWidget {
  final AreaEnsaio selecionada;
  final ValueChanged<AreaEnsaio> onChanged;

  const AbasAreaEnsaio({
    super.key,
    required this.selecionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final area in AreaEnsaio.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(area),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: area == selecionada
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    area.rotulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: area == selecionada
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: area == selecionada
                          ? Colors.white
                          : const Color(0xFF3E3E3D),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
