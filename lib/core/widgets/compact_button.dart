import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CompactButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CompactButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36, // Mesma altura da barra de busca
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // #D99100
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Lato')),
      ),
    );
  }
}