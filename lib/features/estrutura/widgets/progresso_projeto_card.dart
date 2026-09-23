import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../ensaios/ensaios_geral/progresso/progresso_ensaios.dart';

/// Progresso da estrutura no projeto (ensaios realizados ÷ contratados para
/// a empresa, por tipo — ver progresso_ensaios.dart). [progresso] nulo =
/// estrutura sem ensaios contratados.
class ProgressoProjetoCard extends StatelessWidget {
  final double? progresso;
  final String? detalhe;
  final bool carregando;

  const ProgressoProjetoCard({super.key, required this.progresso, this.detalhe, this.carregando = false});

  @override
  Widget build(BuildContext context) {
    final semContrato = !carregando && progresso == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progresso no projeto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: carregando ? null : (progresso ?? 0),
                    backgroundColor: const Color(0xFFE0E0E0),
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                carregando ? '' : textoProgresso(progresso),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (semContrato || detalhe != null) ...[
            const SizedBox(height: 8),
            Text(
              semContrato ? 'Sem ensaios contratados para a sua empresa nesta estrutura.' : detalhe!,
              style: const TextStyle(fontSize: 12, color: AppColors.hintText),
            ),
          ],
        ],
      ),
    );
  }
}
