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
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final canAdd = onChanged != null && isAddEnabled && !isAdding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    validator: validator,
                    style: GoogleFonts.lato(
                      color: onChanged != null
                          ? AppColors.textDark
                          : Colors.grey[600],
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      filled: true,
                      fillColor: onChanged != null
                          ? Colors.white
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorder,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: onChanged != null
                          ? const Color(0xFF313144)
                          : Colors.grey[500],
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
                  color: canAdd || isAdding
                      ? AppColors.primary
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D3A57E8),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: isAdding
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
