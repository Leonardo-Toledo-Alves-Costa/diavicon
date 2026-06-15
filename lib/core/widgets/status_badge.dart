import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum BadgeStatus {
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

  // 🔥 Cor do texto
  Color get _textColor {
    switch (status) {
      case BadgeStatus.emAndamento:
        return AppColors.primary; // O seu Laranja DiaViCon!
      case BadgeStatus.concluido:
        return Colors.green.shade800;
      case BadgeStatus.cancelado:
        return Colors.red.shade700;
    }
  }

  // 🔥 Cor do fundo 100% sólida
  Color get _backgroundColor {
    switch (status) {
      case BadgeStatus.emAndamento:
        return const Color(0xFFFFF3E0); // Laranja clarinho sólido
      case BadgeStatus.concluido:
        return const Color(0xFFE6F4EA); // Verde clarinho sólido
      case BadgeStatus.cancelado:
        return const Color(0xFFFFEBEE); // Vermelho clarinho sólido
    }
  }

  String get _defaultText {
    switch (status) {
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
    final text = customText ?? _defaultText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor, 
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _textColor, 
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}