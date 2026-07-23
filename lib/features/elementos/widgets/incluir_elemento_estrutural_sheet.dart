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

class ElementoEstruturalOption {
  const ElementoEstruturalOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.imageUrl, 
    this.incluido = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final String? imageUrl;

  /// Se o elemento está atualmente incluído (visível) na estrutura. Reflete a
  /// coluna `ativo` no banco; controla o checkbox vir marcado ou não.
  final bool incluido;
}

Future<T?> showIncluirElementoEstruturalSheet<T>({
  required BuildContext context,
  String? estruturaId,
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
      estruturaId: estruturaId,
      elementos: elementos,
      onNovoPressed: onNovoPressed,
    ),
  );
}

class IncluirElementoEstruturalSheet extends ConsumerStatefulWidget {
  const IncluirElementoEstruturalSheet({
    super.key,
    this.estruturaId,
    this.elementos = _defaultElementos,
    this.onNovoPressed,
  });

  /// Estrutura atual. Quando informada, a lista vem do Supabase em tempo real
  /// via [elementosPorEstruturaProvider]; senão, usa [elementos] (mock/demo).
  final String? estruturaId;
  final List<ElementoEstruturalOption> elementos;
  final ValueChanged<List<ElementoEstruturalOption>>? onNovoPressed;

  @override
  ConsumerState<IncluirElementoEstruturalSheet> createState() =>
      _IncluirElementoEstruturalSheetState();
}

class _IncluirElementoEstruturalSheetState
    extends ConsumerState<IncluirElementoEstruturalSheet> {
  final Set<String> _selectedIds = <String>{};

  /// Override otimista da inclusão (modo DB): aplica a mudança no checkbox na
  /// hora do toque, sem esperar o round-trip do banco + re-emissão do stream.
  /// Cada entrada é descartada quando o stream confirma o mesmo valor.
  final Map<String, bool> _inclusaoOverride = <String, bool>{};

  /// Opções atualmente exibidas (mock ou vindas do banco). Mantido para que a
  /// seleção e o callback [onNovoPressed] reflitam a lista real renderizada.
  List<ElementoEstruturalOption> _currentOptions = const [];

  /// `true` quando os elementos vêm do banco: o checkbox reflete a coluna
  /// `ativo` e o toggle persiste a inclusão. `false` no modo mock/demo, onde a
  /// seleção é apenas local ([_selectedIds]).
  bool get _isDbMode => widget.estruturaId != null;

  void _toggle(ElementoEstruturalOption elemento) {
    setState(() {
      if (_selectedIds.contains(elemento.id)) {
        _selectedIds.remove(elemento.id);
        return;
      }
      _selectedIds.add(elemento.id);
    });
  }

  /// Persiste a inclusão/exclusão do elemento (coluna `ativo`). Ao desmarcar,
  /// o elemento some da lista da estrutura mas continua aparecendo aqui
  /// (desmarcado) para poder ser reincluído depois. O stream atualiza sozinho.
  Future<void> _toggleInclusao(ElementoEstruturalOption elemento) async {
    if (!_isDbMode) {
      _toggle(elemento);
      return;
    }
    final novoValor = !(_inclusaoOverride[elemento.id] ?? elemento.incluido);
    setState(() => _inclusaoOverride[elemento.id] = novoValor);
    try {
      await ref
          .read(elementoRepositoryProvider)
          .definirInclusao(elemento.id, novoValor);
    } catch (error) {
      if (!mounted) return;
      // Reverte o override otimista: stream nunca confirmará a mudança.
      setState(() => _inclusaoOverride.remove(elemento.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar inclusão: $error')),
      );
    }
  }

  /// Converte um elemento do banco no modelo de exibição do sheet.
  ElementoEstruturalOption _toOption(ElementoModel elemento) {
    final subtitlePartes = [
      elemento.tipo,
      elemento.tipologiaEstrutural,
    ].where((parte) => parte != null && parte.trim().isNotEmpty).cast<String>();

    // Puxa a primeira URL de foto se existir
    final imageUrl = (elemento.fotos != null && elemento.fotos!.isNotEmpty)
        ? elemento.fotos!.first
        : null;

    return ElementoEstruturalOption(
      id: elemento.id,
      title: (elemento.nome?.trim().isNotEmpty ?? false)
          ? elemento.nome!
          : 'Elemento sem nome',
      subtitle: subtitlePartes.join(' - '),
      detail: elemento.local ?? '',
      imageUrl: imageUrl, 
      incluido: elemento.ativo != false,
    );
  }

  void _handleNovoPressed() {
    final selected = _currentOptions
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
      MaterialPageRoute<void>(
        builder: (_) =>
            NovoElemEstruturalScreen(estruturaId: widget.estruturaId),
      ),
    );
  }

  /// Lista renderizada conforme o estado do carregamento. Em modo mock
  /// ([asyncOptions] nulo) mostra direto; senão trata loading/erro/vazio.
  Widget _buildElementoList(
    AsyncValue<List<ElementoEstruturalOption>>? asyncOptions,
  ) {
    if (asyncOptions == null) {
      return _optionsListView(widget.elementos);
    }

    return asyncOptions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Erro ao carregar elementos',
          style: GoogleFonts.lato(color: const Color(0xFF686868), fontSize: 14),
        ),
      ),
      data: (options) {
        if (options.isEmpty) {
          _currentOptions = const [];
          return Center(
            child: Text(
              'Nenhum elemento cadastrado ainda',
              style: GoogleFonts.lato(
                color: const Color(0xFF686868),
                fontSize: 14,
              ),
            ),
          );
        }
        return _optionsListView(options);
      },
    );
  }

  /// Renderiza os cards selecionáveis e registra as opções exibidas.
  Widget _optionsListView(List<ElementoEstruturalOption> options) {
    _currentOptions = options;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final elemento = options[index];
        // Stream confirmou o override → descarta para voltar à fonte da verdade.
        if (_inclusaoOverride[elemento.id] == elemento.incluido) {
          _inclusaoOverride.remove(elemento.id);
        }
        final isSelected = _isDbMode
            ? (_inclusaoOverride[elemento.id] ?? elemento.incluido)
            : _selectedIds.contains(elemento.id);
        return _ElementoSelectionCard(
          elemento: elemento,
          isSelected: isSelected,
          onTap: () => _toggleInclusao(elemento),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.78).clamp(620.0, 680.0).toDouble();

    final estruturaId = widget.estruturaId;
    final asyncOptions = estruturaId == null
        ? null
        : ref
              .watch(todosElementosPorEstruturaProvider(estruturaId))
              .whenData((lista) => lista.map(_toOption).toList());

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
                    // 🔥 ERRO 1 RESOLVIDO: Passando o estruturaId aqui!
                    if (estruturaId != null) 
                      _EstruturaSummary(estruturaId: estruturaId)
                    else 
                      const SizedBox(),
                    const SizedBox(height: 28),
                    const _FilterRow(),
                    const SizedBox(height: 20),
                    Expanded(child: _buildElementoList(asyncOptions)),
                    const SizedBox(height: 14),
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
            padding: const EdgeInsets.only(top: 23, right: 8), // Dei um respiro na direita
            // 🔥 MÁGICA 1: FittedBox faz a fonte diminuir sozinha se não couber!
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Incluir Elemento Estrutural',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 24, // Tamanho base, ele só diminui se precisar
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
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
                      // 🔥 MÁGICA 2: Aumentei pra 2 linhas pra não cortar nomes longos
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        color: const Color(0xFF3E3E3D),
                        fontSize: 16,
                        fontWeight: FontWeight.w600, // Deixei um tiquinho mais grosso pra ler melhor
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2), // Respiro entre os dois textos
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
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.apartment_outlined,
                color: AppColors.greyDarkest,
                size: 24,
              ),
            )
          : Image.asset(
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
                _ElementoAvatar(imageUrl: elemento.imageUrl), 
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

class _ElementoAvatar extends StatelessWidget {
  const _ElementoAvatar({this.imageUrl}); // 🔥 ERRO 2 RESOLVIDO: Argumento agora é aceito!

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFFE6E7E8), 
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.greyDarkest,
                size: 28,
              ),
            )
          : const Icon( 
              Icons.business_outlined,
              color: AppColors.greyDarkest,
              size: 28,
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