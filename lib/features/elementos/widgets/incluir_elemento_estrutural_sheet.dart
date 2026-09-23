import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/compact_button.dart';
import 'package:diavicon/core/widgets/compact_search_bar.dart';
import 'package:diavicon/core/widgets/item_filter_field.dart';
import 'package:diavicon/core/widgets/local_search_dropdown.dart';
import 'package:diavicon/features/auth/providers/auth_provider.dart';
import 'package:diavicon/features/elementos/models/elemento_model.dart';
import 'package:diavicon/features/elementos/providers/elemento_provider.dart';
import 'package:diavicon/features/elementos/screens/novo_elem_estrutural_screen.dart';
import 'package:diavicon/features/empresa/providers/campos_personalizaveis_provider.dart';
import 'package:diavicon/features/empresa/providers/sistema_provider.dart';
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
    this.tipo,
    this.imageUrl,
    this.incluido = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final String? tipo;
  final String? imageUrl;

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
    useSafeArea: false, 
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
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

  final Map<String, bool> _inclusaoOverride = <String, bool>{};

  List<ElementoEstruturalOption> _currentOptions = const [];

  bool get _isDbMode => widget.estruturaId != null;

  String? _localFiltro;
  String? _sistemaFiltro;
  String? _tipoFiltro;
  final FocusNode _searchFocusNode = FocusNode();

  void _handleSistemaChanged(String? novoSistema) {
    setState(() {
      _sistemaFiltro = novoSistema;

      final empresaId = ref.read(currentUserProvider)?.empresaId;
      if (novoSistema != null && _tipoFiltro != null && empresaId != null) {
        final tipos = ref
            .read(tiposElementoDropdownProvider(empresaId))
            .value;
        final aindaValido = tipos?.any(
              (t) => t.nome == _tipoFiltro && t.sistemaId == novoSistema,
            ) ??
            false;
        if (!aindaValido) {
          _tipoFiltro = null;
        }
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggle(ElementoEstruturalOption elemento) {
    setState(() {
      if (_selectedIds.contains(elemento.id)) {
        _selectedIds.remove(elemento.id);
        return;
      }
      _selectedIds.add(elemento.id);
    });
  }

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
      setState(() => _inclusaoOverride.remove(elemento.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar inclusão: $error')),
      );
    }
  }

  ElementoEstruturalOption _toOption(ElementoModel elemento) {
    final subtitlePartes = [
      elemento.tipo,
      elemento.tipologiaEstrutural,
    ].where((parte) => parte != null && parte.trim().isNotEmpty).cast<String>();

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
      tipo: elemento.tipo,
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
        builder: (_) => NovoElemEstruturalScreen(
          estruturaId: widget.estruturaId,
        ),
      ),
    );
  }

  List<ElementoEstruturalOption> _aplicarFiltros(
    List<ElementoEstruturalOption> options,
    Set<String>? tiposPermitidosPorSistema,
  ) {
    if (_localFiltro != null) {
      options = options.where((e) => e.detail == _localFiltro).toList();
    }
    if (_tipoFiltro != null) {
      options = options.where((e) => e.tipo == _tipoFiltro).toList();
    } else if (tiposPermitidosPorSistema != null) {
      options = options
          .where(
            (e) => e.tipo != null && tiposPermitidosPorSistema.contains(e.tipo),
          )
          .toList();
    }
    return options;
  }

  Widget _buildElementoList(
    AsyncValue<List<ElementoEstruturalOption>>? asyncOptions,
    Set<String>? tiposPermitidosPorSistema,
  ) {
    if (asyncOptions == null) {
      final mockList = _aplicarFiltros(widget.elementos, tiposPermitidosPorSistema);
      return _optionsListView(mockList);
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
        options = _aplicarFiltros(options, tiposPermitidosPorSistema);

        if (options.isEmpty) {
          _currentOptions = const [];
          return Center(
            child: Text(
              'Nenhum elemento encontrado.',
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

  Widget _optionsListView(List<ElementoEstruturalOption> options) {
    _currentOptions = options;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final elemento = options[index];
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
    
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    final sheetHeight = (screenHeight * 0.78).clamp(620.0, 780.0).toDouble() + keyboardHeight * 0.5;

    final estruturaId = widget.estruturaId;
    final asyncOptions = estruturaId == null
        ? null
        : ref
              .watch(todosElementosPorEstruturaProvider(estruturaId))
              .whenData((lista) => lista.map(_toOption).toList());

    final empresaId = ref.watch(currentUserProvider)?.empresaId;
    final tiposAsync = empresaId == null
        ? null
        : ref.watch(tiposElementoDropdownProvider(empresaId));

    Set<String>? tiposPermitidosPorSistema;
    if (_sistemaFiltro != null) {
      final tiposList = tiposAsync?.value;
      if (tiposList != null) {
        tiposPermitidosPorSistema = tiposList
            .where((t) => t.sistemaId == _sistemaFiltro)
            .map((t) => t.nome)
            .toSet();
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container( 
        width: double.infinity,
        height: sheetHeight,
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
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetHeader(onClose: () => Navigator.of(context).pop()),
                    const SizedBox(height: 16),
                    if (estruturaId != null) 
                      _EstruturaSummary(estruturaId: estruturaId)
                    else 
                      const SizedBox(),
                    const SizedBox(height: 28),
                    
                    _FilterRow(
                      estruturaId: estruturaId,
                      empresaId: empresaId,
                      localFiltro: _localFiltro,
                      sistemaFiltro: _sistemaFiltro,
                      tipoFiltro: _tipoFiltro,
                      searchFocusNode: _searchFocusNode,
                      onLocalChanged: (novoLocal) {
                        setState(() {
                          _localFiltro = novoLocal;
                        });
                      },
                      onSistemaChanged: _handleSistemaChanged,
                      onTipoChanged: (novoTipo) {
                        setState(() {
                          _tipoFiltro = novoTipo;
                        });
                      },
                    ),

                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildElementoList(
                        asyncOptions,
                        tiposPermitidosPorSistema,
                      ),
                    ),
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
            padding: const EdgeInsets.only(top: 23, right: 8), 
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Incluir Elemento Estrutural',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 24, 
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

class _FilterRow extends ConsumerWidget {
  final String? estruturaId;
  final String? empresaId;
  final String? localFiltro;
  final String? sistemaFiltro;
  final String? tipoFiltro;
  final ValueChanged<String?> onLocalChanged;
  final ValueChanged<String?> onSistemaChanged;
  final ValueChanged<String?> onTipoChanged;
  final FocusNode searchFocusNode;

  const _FilterRow({
    this.estruturaId,
    this.empresaId,
    this.localFiltro,
    this.sistemaFiltro,
    this.tipoFiltro,
    required this.onLocalChanged,
    required this.onSistemaChanged,
    required this.onTipoChanged,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sistemasAsync = empresaId == null
        ? null
        : ref.watch(sistemasDropdownProvider(empresaId!));
    final tiposAsync = empresaId == null
        ? null
        : ref.watch(tiposElementoDropdownProvider(empresaId!));

    final tiposDoSistema = (tiposAsync?.value ?? const <CampoItemModel>[])
        .where((t) => sistemaFiltro == null || t.sistemaId == sistemaFiltro)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: estruturaId != null
                  ? LocalSearchDropdown(
                      estruturaId: estruturaId!,
                      value: localFiltro,
                      focusNode: searchFocusNode,
                      onChanged: onLocalChanged,
                    )
                  : const CompactSearchBar(hintText: 'Local'),
            ),
            if (localFiltro != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.clear, color: AppColors.error, size: 20),
                onPressed: () => onLocalChanged(null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ItemFilterField(
                hintText: 'Sistema',
                selectedLabel: _labelParaId(
                  sistemasAsync?.value,
                  sistemaFiltro,
                ),
                isLoading: sistemasAsync?.isLoading ?? false,
                onClear: () => onSistemaChanged(null),
                onTap: () async {
                  final itens = (sistemasAsync?.value ?? const <CampoItemModel>[])
                      .map((s) => (value: s.id, label: s.nome))
                      .toList();
                  final resultado = await showItemFilterPickerSheet(
                    context: context,
                    titulo: 'Sistema Habitacional',
                    items: itens,
                    valorSelecionado: sistemaFiltro,
                  );
                  if (resultado == null) return;
                  onSistemaChanged(
                    resultado == kLimparFiltroValue ? null : resultado,
                  );
                },
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ItemFilterField(
                hintText: 'Elemento',
                selectedLabel: tipoFiltro,
                isLoading: tiposAsync?.isLoading ?? false,
                onClear: () => onTipoChanged(null),
                onTap: () async {
                  final itens = tiposDoSistema
                      .map((t) => (value: t.nome, label: t.nome))
                      .toList();
                  final resultado = await showItemFilterPickerSheet(
                    context: context,
                    titulo: 'Tipo de Elemento Estrutural',
                    items: itens,
                    valorSelecionado: tipoFiltro,
                  );
                  if (resultado == null) return;
                  onTipoChanged(
                    resultado == kLimparFiltroValue ? null : resultado,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _labelParaId(List<CampoItemModel>? items, String? id) {
    if (items == null || id == null) return null;
    for (final item in items) {
      if (item.id == id) return item.nome;
    }
    return null;
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
      shadowColor: Colors.black.withValues(alpha: 0.25),
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
  const _ElementoAvatar({this.imageUrl}); 

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
          ? ImagemStorage.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
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
