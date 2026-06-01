import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/compact_search_bar.dart';
import 'package:diavicon/features/elementos/screens/novo_elem_estrutural_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ElementoEstruturalOption {
  const ElementoEstruturalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
  });

  final String id;
  final String title;
  final String subtitle;
  final String detail;
}

Future<T?> showIncluirElementoEstruturalSheet<T>({
  required BuildContext context,
  List<ElementoEstruturalOption> elementos = _defaultElementos,
  ValueChanged<List<ElementoEstruturalOption>>? onNovoPressed,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.42),
    builder: (context) => IncluirElementoEstruturalSheet(
      elementos: elementos,
      onNovoPressed: onNovoPressed,
    ),
  );
}

class IncluirElementoEstruturalSheet extends StatefulWidget {
  const IncluirElementoEstruturalSheet({
    super.key,
    this.elementos = _defaultElementos,
    this.onNovoPressed,
  });

  final List<ElementoEstruturalOption> elementos;
  final ValueChanged<List<ElementoEstruturalOption>>? onNovoPressed;

  @override
  State<IncluirElementoEstruturalSheet> createState() =>
      _IncluirElementoEstruturalSheetState();
}

class _IncluirElementoEstruturalSheetState
    extends State<IncluirElementoEstruturalSheet> {
  final Set<String> _selectedIds = <String>{};

  void _toggle(ElementoEstruturalOption elemento) {
    setState(() {
      if (_selectedIds.contains(elemento.id)) {
        _selectedIds.remove(elemento.id);
        return;
      }
      _selectedIds.add(elemento.id);
    });
  }

  void _handleNovoPressed() {
    final selected = widget.elementos
        .where((elemento) => _selectedIds.contains(elemento.id))
        .toList();
    final navigator = Navigator.of(context);

    if (widget.onNovoPressed != null) {
      widget.onNovoPressed!(selected);
      navigator.pop();
      return;
    }

    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NovoElemEstruturalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.78).clamp(620.0, 680.0).toDouble();

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        height: sheetHeight,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 346),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.25),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 27),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(onClose: () => Navigator.of(context).pop()),
                    const SizedBox(height: 16),
                    const _EstruturaSummary(),
                    const SizedBox(height: 28),
                    const _FilterRow(),
                    const SizedBox(height: 20),
                    for (final elemento in widget.elementos) ...[
                      _ElementoSelectionCard(
                        elemento: elemento,
                        isSelected: _selectedIds.contains(elemento.id),
                        onTap: () => _toggle(elemento),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 119,
                        child: CompactButton(
                          text: 'Novo',
                          onPressed: _handleNovoPressed,
                        ),
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

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 21),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 23),
            child: Text(
              'Incluir Elemento Estrutural',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                color: const Color(0xFF3E3E3D),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Color(0xFF8F8F8F), size: 24),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        ),
      ],
    );
  }
}

class _EstruturaSummary extends StatelessWidget {
  const _EstruturaSummary();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Row(
        children: [
          const _StructureAvatar(),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estrutura BCDE',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              Text(
                'Conjunto Estrutural A',
                style: GoogleFonts.lato(
                  color: const Color(0xFF686868),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StructureAvatar extends StatelessWidget {
  const _StructureAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFE6E7E8),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/obra.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.apartment_outlined,
          color: AppColors.greyDarkest,
          size: 24,
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 7, child: CompactSearchBar(hintText: 'Local')),
        SizedBox(width: 9),
        Expanded(flex: 6, child: _ElementoFilterField()),
      ],
    );
  }
}

class _ElementoFilterField extends StatelessWidget {
  const _ElementoFilterField();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.inputBorder),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Elemento',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: AppColors.hintText.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const Icon(Icons.tune, color: AppColors.primary, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElementoSelectionCard extends StatelessWidget {
  const _ElementoSelectionCard({
    required this.elemento,
    required this.isSelected,
    required this.onTap,
  });

  final ElementoEstruturalOption elemento;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFAFA),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 86,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 15, 12),
            child: Row(
              children: [
                const _CompanyAvatar(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elemento.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF3E3E3D),
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        elemento.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF686868),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        elemento.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF686868),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SelectionBox(isSelected: isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/empresa.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.business_outlined,
          color: AppColors.greyDarkest,
          size: 28,
        ),
      ),
    );
  }
}

class _SelectionBox extends StatelessWidget {
  const _SelectionBox({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFF686868),
          width: 1.2,
        ),
      ),
      child: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : null,
    );
  }
}

const List<ElementoEstruturalOption> _defaultElementos =
    <ElementoEstruturalOption>[
      ElementoEstruturalOption(
        id: 'v201',
        title: 'V201',
        subtitle: 'Viga - Concreto armado',
        detail: 'Casa de máquinas',
      ),
      ElementoEstruturalOption(
        id: 'p102',
        title: 'P102',
        subtitle: 'Pilar - Concreto armado',
        detail: '1ª Subsolo',
      ),
    ];
