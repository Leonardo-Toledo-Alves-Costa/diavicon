import 'package:diavicon/features/estrutura/models/local_model.dart';
import 'package:diavicon/features/estrutura/providers/local_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart'; 

class LocalSearchDropdown extends ConsumerWidget {
  final String estruturaId;
  final String? value;
  final ValueChanged<String?> onChanged;

  const LocalSearchDropdown({
    super.key,
    required this.estruturaId,
    this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locaisAsync = ref.watch(locaisPorEstruturaProvider(estruturaId));

    return locaisAsync.when(
      loading: () => _buildDisabledField(isLoading: true),
      error: (e, _) => _buildDisabledField(isError: true),
      data: (List<LocalModel> locais) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              width: constraints.maxWidth,
              initialSelection: value,
              enableFilter: true, // Digitar para buscar
              enableSearch: true,
              requestFocusOnTap: true,
              hintText: 'Local',
              textStyle: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D)),
              menuHeight: 250,
              trailingIcon: const Icon(Icons.search, size: 19, color: AppColors.primary),
              selectedTrailingIcon: const Icon(Icons.search, size: 19, color: AppColors.primary),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                hintStyle: GoogleFonts.lato(color: AppColors.hintText.withOpacity(0.45), fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              dropdownMenuEntries: locais.map((local) {
                final nomeLocal = local.nome ?? 'Sem nome'; 
                
                return DropdownMenuEntry<String>(

                  value: nomeLocal, 
                  label: nomeLocal,
                  style: MenuItemButton.styleFrom(
                    foregroundColor: const Color(0xFF3E3E3D),
                    textStyle: GoogleFonts.lato(fontSize: 14),
                  ),
                );
              }).toList(),
              onSelected: onChanged,
            );
          },
        );
      },
    );
  }

  // Widget auxiliar para loading e erro
  Widget _buildDisabledField({bool isLoading = false, bool isError = false}) {
    return SizedBox(
      height: 36,
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          hintText: isError ? 'Erro' : (isLoading ? 'Carregando...' : 'Local'),
          hintStyle: GoogleFonts.lato(color: AppColors.hintText.withOpacity(0.45), fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.inputBorder),
          ),
          suffixIcon: isLoading 
              ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Icon(Icons.search, size: 19, color: AppColors.primary),
        ),
      ),
    );
  }
}