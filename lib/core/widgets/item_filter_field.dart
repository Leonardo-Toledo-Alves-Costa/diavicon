import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'compact_search_bar.dart';

/// Sentinela retornada pelo picker quando o usuário toca em "Limpar filtro",
/// distinguindo essa ação de um simples cancelamento (que retorna `null`).
const String kLimparFiltroValue = ' __limpar_filtro__';

/// Abre um bottom sheet de seleção única com busca, usado pelos filtros
/// compactos ([ItemFilterField]) espalhados pelo app.
///
/// Retorna `null` quando o usuário cancela (fecha sem escolher nada) —
/// nesse caso o chamador não deve alterar o filtro atual. Retorna
/// [kLimparFiltroValue] quando o usuário toca em "Limpar filtro" — o
/// chamador deve tratar isso como limpar a seleção (`onChanged(null)`).
/// Qualquer outro valor não-nulo é o item selecionado.
Future<String?> showItemFilterPickerSheet({
  required BuildContext context,
  required String titulo,
  required List<({String value, String label})> items,
  required String? valorSelecionado,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => _FilterPickerSheet(
      titulo: titulo,
      items: items,
      valorSelecionado: valorSelecionado,
    ),
  );
}

/// Campo compacto (pill) que exibe o valor selecionado de um filtro e,
/// ao ser tocado, deve abrir um [showItemFilterPickerSheet]. Mostra um "x"
/// para limpar quando há um valor selecionado.
class ItemFilterField extends StatelessWidget {
  const ItemFilterField({
    super.key,
    required this.hintText,
    required this.selectedLabel,
    required this.onTap,
    required this.onClear,
    this.isLoading = false,
  });

  final String hintText;
  final String? selectedLabel;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedLabel != null;

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.only(left: 14, right: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasValue ? AppColors.primary : AppColors.inputBorder,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabel ?? hintText,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: hasValue
                              ? const Color(0xFF3E3E3D)
                              : AppColors.hintText.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.expand_more_rounded,
                        color: hasValue ? AppColors.primary : const Color(0xFF8F8F8F),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasValue) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.clear, color: AppColors.error, size: 20),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }
}

class _FilterPickerSheet extends StatefulWidget {
  const _FilterPickerSheet({
    required this.titulo,
    required this.items,
    required this.valorSelecionado,
  });

  final String titulo;
  final List<({String value, String label})> items;
  final String? valorSelecionado;

  @override
  State<_FilterPickerSheet> createState() => _FilterPickerSheetState();
}

class _FilterPickerSheetState extends State<_FilterPickerSheet> {
  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.7).clamp(320.0, 560.0).toDouble();

    final itensFiltrados = _busca.trim().isEmpty
        ? widget.items
        : widget.items
              .where(
                (item) =>
                    item.label.toLowerCase().contains(_busca.toLowerCase()),
              )
              .toList();

    final mostrarLimpar = widget.valorSelecionado != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: maxHeight),
        margin: EdgeInsets.only(bottom: safeBottom + 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 346),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.titulo,
                            style: GoogleFonts.lato(
                              color: const Color(0xFF3E3E3D),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF8F8F8F),
                            size: 22,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CompactSearchBar(
                      hintText: 'Buscar',
                      controller: _buscaController,
                      onChanged: (valor) => setState(() => _busca = valor),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: itensFiltrados.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Nenhum item encontrado.',
                                  style: GoogleFonts.lato(
                                    color: const Color(0xFF686868),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount:
                                  itensFiltrados.length + (mostrarLimpar ? 1 : 0),
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: Color(0xFFEFEFEF),
                              ),
                              itemBuilder: (context, index) {
                                if (mostrarLimpar && index == 0) {
                                  return _PickerTile(
                                    label: 'Limpar filtro',
                                    icon: Icons.filter_alt_off_outlined,
                                    isDestructive: true,
                                    onTap: () => Navigator.of(
                                      context,
                                    ).pop<String?>(kLimparFiltroValue),
                                  );
                                }
                                final item =
                                    itensFiltrados[index - (mostrarLimpar ? 1 : 0)];
                                return _PickerTile(
                                  label: item.label,
                                  isSelected:
                                      item.value == widget.valorSelecionado,
                                  onTap: () => Navigator.of(
                                    context,
                                  ).pop<String?>(item.value),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.isDestructive = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isDestructive;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final corTexto = isDestructive
        ? AppColors.error
        : (isSelected ? AppColors.primary : const Color(0xFF3E3E3D));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: corTexto, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  color: corTexto,
                  fontSize: 15,
                  fontWeight: (isSelected || isDestructive)
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
