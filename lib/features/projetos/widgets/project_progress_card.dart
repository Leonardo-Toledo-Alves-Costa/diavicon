import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ProjectProgressCard extends StatelessWidget {
  final double progresso;
  
  const ProjectProgressCard({
    super.key, 
    required this.progresso,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Fundo laranja bem claro
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
                '${(progresso * 100).toInt()}%',
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
              value: progresso,
              backgroundColor: const Color(0xFFE0E0E0),
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}