import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomLabel extends StatelessWidget {
  final String text;
  final String? tooltip;

  const CustomLabel({
    super.key,
    required this.text,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textDark, 
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        
        if (tooltip != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            triggerMode: TooltipTriggerMode.tap, 
            showDuration: const Duration(seconds: 3),
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.textDark.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(color: AppColors.white, fontSize: 12),
            child: const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}