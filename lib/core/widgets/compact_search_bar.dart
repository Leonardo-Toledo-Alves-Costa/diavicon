import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class CompactSearchBar extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const CompactSearchBar({
    super.key,
    this.hintText = 'Nome da estrutura',
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.centerLeft, // Força o alinhamento no centro vertical
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        autofocus: false,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textDark,
          fontFamily: 'Lato',
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFFBDBDBD),
            fontSize: 10.5,
            fontFamily: 'Lato',
          ),
          suffixIcon: const Icon(
            Icons.search,
            color: Color(0xFF757575),
            size: 16,
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 35),

          contentPadding: const EdgeInsets.fromLTRB(12, 8, 0, 8),

          border: InputBorder.none,
        ),
      ),
    );
  }
}
