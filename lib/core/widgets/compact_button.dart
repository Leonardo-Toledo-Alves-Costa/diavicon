import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CompactButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final double? width;
  
  // 🔥 NOVO: Parâmetros opcionais para o botão ser super flexível
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? iconColor;
  final Color? borderColor;
  final double elevation;

  const CompactButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.width,
    this.height = 40,
    this.backgroundColor,
    this.foregroundColor,
    this.iconColor,
    this.borderColor,
    this.elevation = 2,
  });

  @override
  Widget build(BuildContext context) {
    // Se não passarmos cor, ele assume o padrão (Laranja e Branco)
    final bg = backgroundColor ?? AppColors.primary;
    final fg = foregroundColor ?? Colors.white;
    final iColor = iconColor ?? fg;

    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          padding: const EdgeInsets.symmetric(horizontal: 12), // Reduzido um pouco para caber textos grandes
          shape: StadiumBorder(
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1.2)
                : BorderSide.none,
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iColor),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center, // 🔥 Importante para o \n funcionar bem
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500, // Um pouco mais forte para leitura
                  fontFamily: 'Lato',
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}