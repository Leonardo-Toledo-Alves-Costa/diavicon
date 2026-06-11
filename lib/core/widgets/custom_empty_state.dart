import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomEmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  const CustomEmptyState({
    super.key,
    required this.text,
    this.icon = Icons.priority_high_rounded, // Exclamação padrão
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300, 
                  width: 4, // 🔥 Engrossado de 2 para 3 para ficar igual ao print!
                ),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}