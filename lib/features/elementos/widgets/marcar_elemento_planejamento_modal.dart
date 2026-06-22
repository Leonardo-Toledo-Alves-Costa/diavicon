import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/compact_search_bar.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/screens/novo_elem_estrutural_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class MarcarElementoPlanejamentoModal extends ConsumerWidget {
  const MarcarElementoPlanejamentoModal({super.key, required this.estruturaId});

  final String estruturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.78).clamp(620.0, 680.0).toDouble();

    final elementosAsync = ref.watch(todosElementosPorEstruturaProvider(estruturaId));

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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                    Expanded(
                      child: elementosAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Erro: $e')),
                        data: (elementos) {
                          // 🔥 Só mostra elementos que não têm planta associada!
                          final naoPosicionados = elementos.where((el) => el.plantaId == null && el.ativo != false).toList();
                          
                          if (naoPosicionados.isEmpty) {
                            return Center(
                              child: Text(
                                'Nenhum elemento livre.\nCrie um novo elemento.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.lato(color: const Color(0xFF686868), fontSize: 14),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: naoPosicionados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final el = naoPosicionados[index];
                              return _ElementoCard(
                                elemento: el,
                                // 🔥 Retorna o elemento clicado para a tela anterior
                                onTap: () => Navigator.of(context).pop(el), 
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 119,
                        child: CompactButton(
                          text: 'Novo',
                          onPressed: () {
                            Navigator.pop(context); // Fecha o sheet
                            Navigator.push(context, MaterialPageRoute(builder: (_) => NovoElemEstruturalScreen(estruturaId: estruturaId)));
                          },
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

// --- Componentes Internos do Sheet ---

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
            child: Text('Marcar elemento em planta', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 24, fontWeight: FontWeight.w800, height: 1.05)),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Color(0xFF8F8F8F), size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 36, height: 36)),
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
          Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFE6E7E8), shape: BoxShape.circle), clipBehavior: Clip.antiAlias, child: Image.asset('assets/images/obra.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.apartment_outlined, color: AppColors.greyDarkest, size: 24))),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estrutura BCDE', style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 16, fontWeight: FontWeight.w400, height: 1.1)),
              Text('Conjunto Estrutural A', style: GoogleFonts.lato(color: const Color(0xFF686868), fontSize: 14, fontWeight: FontWeight.w300, height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(flex: 7, child: CompactSearchBar(hintText: 'Local')),
        const SizedBox(width: 9),
        Expanded(
          flex: 6, 
          child: SizedBox(height: 36, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(22)), child: Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: Row(children: [Expanded(child: Text('Elemento', overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: AppColors.hintText.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w400))), const Icon(Icons.tune, color: AppColors.primary, size: 19)])))),
        ),
      ],
    );
  }
}

class _ElementoCard extends StatelessWidget {
  const _ElementoCard({required this.elemento, required this.onTap});
  final ElementoModel elemento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [elemento.tipo, elemento.tipologiaEstrutural].where((p) => p != null && p.trim().isNotEmpty).join(' - ');
    final imgUrl = (elemento.fotos != null && elemento.fotos!.isNotEmpty) ? elemento.fotos!.first : null;

    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
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
                Container(width: 54, height: 54, decoration: const BoxDecoration(color: Color(0xFFE6E7E8), shape: BoxShape.circle), clipBehavior: Clip.antiAlias, child: imgUrl != null ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=> const Icon(Icons.broken_image_outlined, color: AppColors.greyDarkest)) : const Icon(Icons.business_outlined, color: AppColors.greyDarkest, size: 28)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(elemento.nome ?? 'Sem nome', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: const Color(0xFF3E3E3D), fontSize: 18, fontWeight: FontWeight.w400, height: 1.1)),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: const Color(0xFF686868), fontSize: 14, fontWeight: FontWeight.w300, height: 1.1)),
                      const SizedBox(height: 4),
                      Text(elemento.local ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: const Color(0xFF686868), fontSize: 14, fontWeight: FontWeight.w300, height: 1.1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}