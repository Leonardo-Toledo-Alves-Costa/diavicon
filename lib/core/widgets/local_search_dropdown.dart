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
  
  final FocusNode? focusNode; 

  /// Quando informado, adiciona uma primeira entrada com este rotulo que
  /// LIMPA a selecao (devolve null em [onChanged]). Serve pros usos como
  /// filtro de lista, onde "nenhum local escolhido" e um estado valido; nos
  /// usos como campo de formulario fica de fora, porque ali o local e
  /// obrigatorio.
  final String? rotuloTodos;

  const LocalSearchDropdown({
    super.key,
    required this.estruturaId,
    this.value,
    required this.onChanged,
    this.focusNode,
    this.rotuloTodos, 
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
              focusNode: focusNode, 
              width: constraints.maxWidth,
              initialSelection: value,
              enableFilter: true, 
              enableSearch: true,
              requestFocusOnTap: true,
              hintText: 'Local',
              textStyle: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
              menuHeight: 250,
              
              trailingIcon: const Icon(Icons.search, size: 18, color: Color(0xFF757575)),
              selectedTrailingIcon: const Icon(Icons.search, size: 18, color: Color(0xFF757575)),
              
              menuStyle: MenuStyle(
                backgroundColor: WidgetStateProperty.all(Colors.white),
                surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                elevation: WidgetStateProperty.all(4),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                isDense: true, 
                constraints: const BoxConstraints(maxHeight: 36, minHeight: 36), 
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                hintStyle: GoogleFonts.lato(color: AppColors.hintText.withValues(alpha: 0.6), fontSize: 13),
                
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              dropdownMenuEntries: [
                if (rotuloTodos != null)
                  DropdownMenuEntry<String>(
                    // String vazia como sentinela de "sem filtro": o menu e
                    // tipado como DropdownMenuEntry<String>, entao null nao
                    // cabe como valor de entrada. A traducao pra null
                    // acontece no onSelected.
                    value: '',
                    label: rotuloTodos!,
                    style: MenuItemButton.styleFrom(
                      foregroundColor: const Color(0xFF3E3E3D),
                      textStyle: GoogleFonts.lato(fontSize: 14),
                    ),
                  ),
                ...locais.map((local) {
                final nomeLocal = local.nome ?? 'Sem nome'; 
                
                return DropdownMenuEntry<String>(
                  value: nomeLocal, 
                  label: nomeLocal,
                  style: MenuItemButton.styleFrom(
                    foregroundColor: const Color(0xFF3E3E3D),
                    textStyle: GoogleFonts.lato(fontSize: 14),
                  ),
                );
              }),
              ],
              onSelected: (valor) =>
                  onChanged((valor == null || valor.isEmpty) ? null : valor),
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
          isDense: true,
          constraints: const BoxConstraints(maxHeight: 36, minHeight: 36),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          hintText: isError ? 'Erro' : (isLoading ? 'Carregando...' : 'Local'),
          hintStyle: GoogleFonts.lato(color: AppColors.hintText.withValues(alpha: 0.6), fontSize: 13),
          
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          suffixIcon: isLoading 
              ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Icon(Icons.search, size: 18, color: Color(0xFF757575)),
        ),
      ),
    );
  }
}