import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Remove itens com valor repetido (fica o primeiro). O DropdownButton do
/// Flutter derruba a tela (assert "There should be exactly one item with
/// [DropdownButton]'s value") quando dois itens têm o mesmo valor — e isso
/// acontece com listas que juntam o padrão DIAVICON com o da empresa e usam
/// o NOME como valor (ex.: "Industrial" nas duas).
List<DropdownMenuItem<T>> itensDropdownSemRepetidos<T>(List<DropdownMenuItem<T>> itens) {
  final vistos = <T?>{};
  return [for (final item in itens) if (vistos.add(item.value)) item];
}

/// Valor que o dropdown consegue exibir: `null` se não estiver entre os itens
/// (ex.: opção apagada do cadastro), em vez de derrubar a tela.
T? valorDropdownSeguro<T>(T? valor, List<DropdownMenuItem<T>> itens) =>
    valor != null && itens.any((i) => i.value == valor) ? valor : null;

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final String? tooltip;
  final bool isRequired;
  final String? Function(T?)? validator;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint = 'Selecione',
    this.tooltip,
    this.isRequired = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final itensSeguros = itensDropdownSemRepetidos(items);
    final valorSeguro = valorDropdownSeguro(value, itensSeguros);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
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
                  showDuration: const Duration(seconds: 2),
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
        ],
        DropdownButtonFormField<T>(
          initialValue: valorSeguro,
          isExpanded: true,
          items: itensSeguros,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.lato(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: 0.54,
          ),
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Faz a mágica do "Seleci..."
            style: GoogleFonts.lato(
              color: AppColors.hintText,
              fontSize: 18,
              fontWeight: FontWeight.w300,
              height: 1,
              letterSpacing: 0.54,
            ),
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.white,
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
      ],
    );
  }
}
