import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/compact_search_bar.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/screens/novo_elem_estrutural_screen.dart';
import 'package:diavicon/features/estrutura/providers/estrutura_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class MarcarElementoPlanejamentoModal extends ConsumerWidget {
  const MarcarElementoPlanejamentoModal({super.key, required this.estruturaId});

  final String estruturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Pega a altura da barra de navegação do celular
    final bottomPadding = MediaQuery.of(context).padding.bottom; 
    
    //  Soma ela na altura do sheet para não espremer a lista
    final sheetHeight = (screenHeight * 0.78).clamp(620.0, 680.0).toDouble() + bottomPadding;

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
              shadowColor: Colors.black.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                // Soma o padding bottom aqui no EdgeInsets
                padding: EdgeInsets.fromLTRB(14, 16, 14, 27 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(onClose: () => Navigator.of(context).pop()),
                    const SizedBox(height: 16),
                    _EstruturaSummary(estruturaId: estruturaId),
                    const SizedBox(height: 28),
                    const _FilterRow(),
                    const SizedBox(height: 20),
                    Expanded(
                      child: elementosAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Erro: $e')),
                        data: (elementos) {
                          //  Só mostra elementos que não têm planta associada
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
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final el = naoPosicionados[index];
                              return _ElementoCard(
                                elemento: el,
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
            padding: const EdgeInsets.only(top: 23, right: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Marcar elemento em planta', 
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D), 
                  fontSize: 24, 
                  fontWeight: FontWeight.w800, 
                  height: 1.05
                ),
              ),
            ),
          ),
        ),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Color(0xFF8F8F8F), size: 24), padding: EdgeInsets.zero, constraints: const BoxConstraints.tightFor(width: 36, height: 36)),
      ],
    );
  }
}

class _EstruturaSummary extends ConsumerWidget {
  const _EstruturaSummary({required this.estruturaId});
  
  final String estruturaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(estruturaResumoProvider(estruturaId));

    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: asyncData.when(
        loading: () => const SizedBox(height: 38, width: 38, child: CircularProgressIndicator(strokeWidth: 2)),
        error: (err, _) => Text('Erro: $err', style: const TextStyle(color: Colors.red, fontSize: 12)),
        data: (data) {
          if (data == null) return const SizedBox();

          final nomeEstrutura = data['nome'] ?? 'Estrutura sem nome';
          
          final conjuntoMap = data['conjuntos_estruturais'];
          String nomeConjunto = 'Sem conjunto estrutural';
          if (conjuntoMap is Map) {
            nomeConjunto = conjuntoMap['nome'] ?? nomeConjunto;
          } else if (conjuntoMap is List && conjuntoMap.isNotEmpty) {
             nomeConjunto = conjuntoMap.first['nome'] ?? nomeConjunto;
          }

          final imageUrl = data['image_url'];

          return Row(
            children: [
              _StructureAvatar(imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeEstrutura,
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        color: const Color(0xFF3E3E3D),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nomeConjunto,
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
            ],
          );
        },
      ),
    );
  }
}

class _StructureAvatar extends StatelessWidget {
  const _StructureAvatar({this.imageUrl});
  
  final String? imageUrl;

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
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ImagemStorage.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.apartment_outlined,
                color: AppColors.greyDarkest,
                size: 24,
              ),
            )
          : Image.asset(
              'assets/images/obra.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
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
    return Row(
      children: [
        const Expanded(flex: 7, child: CompactSearchBar(hintText: 'Local')),
        const SizedBox(width: 9),
        Expanded(
          flex: 6, 
          child: SizedBox(height: 36, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.inputBorder), borderRadius: BorderRadius.circular(22)), child: Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: Row(children: [Expanded(child: Text('Elemento', overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: AppColors.hintText.withValues(alpha: 0.45), fontSize: 12, fontWeight: FontWeight.w400))), const Icon(Icons.tune, color: AppColors.primary, size: 19)])))),
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
      shadowColor: Colors.black.withValues(alpha: 0.15),
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
                Container(width: 54, height: 54, decoration: const BoxDecoration(color: Color(0xFFE6E7E8), shape: BoxShape.circle), clipBehavior: Clip.antiAlias, child: imgUrl != null ? ImagemStorage.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,_,_)=> const Icon(Icons.broken_image_outlined, color: AppColors.greyDarkest)) : const Icon(Icons.business_outlined, color: AppColors.greyDarkest, size: 28)),
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