import 'package:flutter/material.dart';

class MainBottomBarPainter extends CustomPainter {
  final double humpWidth;
  final double humpHeight;

  const MainBottomBarPainter({
    required this.humpWidth,
    required this.humpHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = size.width / 2;
    final path = Path()
      ..moveTo(0, humpHeight)
      ..lineTo(center - humpWidth / 2, humpHeight)
      ..cubicTo(
        center - humpWidth / 3,
        humpHeight,
        center - humpWidth / 2.5,
        0,
        center,
        0,
      )
      ..cubicTo(
        center + humpWidth / 2.5,
        0,
        center + humpWidth / 3,
        humpHeight,
        center + humpWidth / 2,
        humpHeight,
      )
      ..lineTo(size.width, humpHeight)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Sombra sozinha é sutil demais pra marcar o relevo em algumas telas —
    // some quando o dispositivo renderiza a sombra fraca, deixando a barra
    // parecer um retângulo liso sem contorno. Um traço fino resolve isso
    // independentemente da sombra.
    final contorno = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.18), 12, false);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, contorno);
  }

  @override
  bool shouldRepaint(covariant MainBottomBarPainter oldDelegate) {
    return oldDelegate.humpWidth != humpWidth ||
        oldDelegate.humpHeight != humpHeight;
  }
}
