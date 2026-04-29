import 'package:flutter/material.dart';
import '../constants/app_colors.dart'; 

class CustomDropdownWithAdd<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final VoidCallback onAddPressed; 

  const CustomDropdownWithAdd({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    required this.onAddPressed,
    this.value,
    this.hint = 'Selecione',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: DropdownButtonFormField<T>(
                initialValue: value,
                items: items,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            
            InkWell(
              onTap: onAddPressed,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}