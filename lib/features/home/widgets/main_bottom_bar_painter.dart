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

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.12), 12, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MainBottomBarPainter oldDelegate) {
    return oldDelegate.humpWidth != humpWidth ||
        oldDelegate.humpHeight != humpHeight;
  }
}
