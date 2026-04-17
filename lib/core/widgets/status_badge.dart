import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeStatus {
  pendente,
  emAndamento,
  concluido,
  cancelado,
}

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;
  final String? customText; 

  const StatusBadge({
    super.key,
    required this.status,
    this.customText,
  });

  Color get _baseColor {
    switch (status) {
      case BadgeStatus.pendente:
        return AppColors.primary; 
      case BadgeStatus.emAndamento:
        return Colors.blue;
      case BadgeStatus.concluido:
        return Colors.green;
      case BadgeStatus.cancelado:
        return Colors.red;
    }
  }

  String get _defaultText {
    switch (status) {
      case BadgeStatus.pendente:
        return 'Pendente';
      case BadgeStatus.emAndamento:
        return 'Em Andamento';
      case BadgeStatus.concluido:
        return 'Concluído';
      case BadgeStatus.cancelado:
        return 'Cancelado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _baseColor;
    final text = customText ?? _defaultText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}