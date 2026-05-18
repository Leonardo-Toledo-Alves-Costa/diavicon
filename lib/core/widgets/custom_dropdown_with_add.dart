import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomDropdownWithAdd<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hint;
  final VoidCallback onAddPressed;
  final bool isRequired; // 🚨 NOVO PARÂMETRO

  const CustomDropdownWithAdd({
    super.key,
    required this.label,
    required this.items,
    this.onChanged,
    required this.onAddPressed,
    this.value,
    this.hint = 'Selecione',
    this.isRequired = false, // 🚨 Padrão é falso
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🚨 RICH TEXT PARA O ASTERISCO COLORIDO
        RichText(
          text: TextSpan(
            text: label.replaceAll('*', '').trim(),
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter', // Caso use fonte customizada, o RichText pede
            ),
            children: [
              if (isRequired || label.contains('*'))
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.primary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (isKeyboardOpen) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                child: AbsorbPointer(
                  absorbing: isKeyboardOpen,
                  child: DropdownButtonFormField<T>(
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: AppColors.hintText, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: onChanged != null ? AppColors.white : Colors.grey[100],
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
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    style: TextStyle(
                      color: onChanged != null ? AppColors.textDark : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onChanged != null ? onAddPressed : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: onChanged != null ? AppColors.primary : Colors.grey[400],
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