import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class Customtextbutton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;

  const Customtextbutton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      onPressed: () => onPressed,
    );
  }
}
