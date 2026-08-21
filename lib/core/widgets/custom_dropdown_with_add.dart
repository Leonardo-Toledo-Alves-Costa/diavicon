import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class CustomDropdownWithAdd<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hint;
  final VoidCallback onAddPressed;
  final bool isRequired;
  final String? Function(T?)? validator;
  final bool isAddEnabled;
  final bool isAdding;
  final String? tooltip; // 🔥 Adicionado o tooltip aqui!

  const CustomDropdownWithAdd({
    super.key,
    required this.label,
    required this.items,
    this.onChanged,
    required this.onAddPressed,
    this.value,
    this.hint = 'Selecione',
    this.isRequired = false,
    this.validator,
    this.isAddEnabled = true,
    this.isAdding = false,
    this.tooltip, // 🔥 E aqui!
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final canAdd = onChanged != null && isAddEnabled && !isAdding;

    final bool valueExists = value == null || items.any((item) => item.value == value);
    final T? safeValue = valueExists ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔥 Bloco do Label igual ao do CustomDropdown (com o ícone de info)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                text: label.replaceAll('*', '').trim(),
                style: GoogleFonts.lato(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w300,
                  height: 1,
                ),
                children: [
                  if (isRequired || label.contains('*'))
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip!,
                triggerMode: TooltipTriggerMode.tap,
                preferBelow: false,
                showDuration: const Duration(seconds: 3),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                textStyle: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.greyLight,
                ),
              ),
            ],
          ],
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
                    isExpanded: true,
                    initialValue: safeValue,
                    items: items,
                    onChanged: onChanged,
                    validator: validator,
                    style: GoogleFonts.lato(
                      color: onChanged != null ? AppColors.textDark : Colors.grey[600],
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      height: 1,
                      letterSpacing: 0.54,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.lato(
                        color: AppColors.hintText,
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        height: 1,
                        letterSpacing: 0.54,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      filled: true,
                      fillColor: onChanged != null ? Colors.white : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: onChanged != null ? const Color(0xFF313144) : Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: canAdd ? onAddPressed : null,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: canAdd || isAdding ? AppColors.primary : Colors.grey[400],
                  shape: BoxShape.circle,
                  boxShadow: const [BoxShadow(color: Color(0x4D3A57E8), offset: Offset(0, 2), blurRadius: 4)],
                ),
                child: isAdding
                    ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))))
                    : const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}