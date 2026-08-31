import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final bool? enabled;
  final bool isRequired;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final int? maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.enabled,
    this.isRequired = false,
    this.inputFormatters,
    this.prefixIcon,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled ?? true;

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
        TextFormField(
          inputFormatters: inputFormatters,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          style: GoogleFonts.lato(
            color: isEnabled ? AppColors.textDark : Colors.grey[600],
            fontSize: 18,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: 0.54,
          ),
          maxLines: obscureText ? 1 : maxLines,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 16.0,
            ),

            hintStyle: GoogleFonts.lato(
              color: AppColors.hintText,
              fontSize: 18,
              fontWeight: FontWeight.w300,
              height: 1,
              letterSpacing: 0.54,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey[100],
            prefixIcon: prefixIcon,
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
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
