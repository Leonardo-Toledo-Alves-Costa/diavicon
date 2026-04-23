import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Barra de progresso por etapas usada nas telas de cadastro.
/// Exemplo de uso: StepProgressBar(currentStep: 1, totalSteps: 3)
class StepProgressBar extends StatelessWidget {
  final int currentStep;  // etapa atual (começa em 1)
  final int totalSteps;   // total de etapas

  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.primary : AppColors.greyVeryLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}