import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/core/widgets/local_search_dropdown.dart';
import 'package:diavicon/features/elementos/screens/elemento_form_screen.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/screens/estrutura_ensaios_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';
import '../../elementos/models/elemento_model.dart';
import '../../elementos/providers/elemento_provider.dart';
import '../../elementos/screens/planejamento_plantas_screen.dart';
import '../../elementos/widgets/incluir_elemento_estrutural_sheet.dart';
import '../models/estrutura_model.dart';
import '../providers/estrutura_provider.dart';
import '../widgets/elemento_estrutural_card.dart';
import '../widgets/estrutura_home_header.dart';
import '../widgets/progresso_projeto_card.dart';
import 'estrutura_informacao_screen.dart';

class EstruturaHomeScreen extends ConsumerStatefulWidget {
  final EstruturaModel estrutura;
  final String projetoId;

  const EstruturaHomeScreen({
    super.key,
    required this.estrutura,
    required this.projetoId,
  });

  @override
  ConsumerState<EstruturaHomeScreen> createState() =>
      _EstruturaHomeScreenState();
}

class _EstruturaHomeScreenState extends ConsumerState<EstruturaHomeScreen> {
  String? _localFiltro;

  void _openElemento(
    BuildContext context, {
    required String elementoId,
    required String titulo,
    required String tipo,
    required String local,
    required String imageUrl,
    String? marcacaoImagemUrl,
  }) {
    context.push(
      '/estruturas/${widget.estrutura.id}/elementos/$elementoId',
      extra: <String, dynamic>{
        'projetoId': widget.projetoId,
        'estruturaId': widget.estrutura.id,
        'elementoId': elementoId,
        'titulo': titulo,
        'tipo': tipo,
        'local': local,
        'imageUrl': imageUrl,
        if (marcacaoImagemUrl != null) 'marcacaoImagemUrl': marcacaoImagemUrl,
      },
    );
  }

  Future<void> _incluirElemento(BuildContext context, WidgetRef ref) async {
    await showIncluirElementoEstruturalSheet<void>(
      context: context,
      estruturaId: widget.estrutura.id,
    );
    ref.invalidate(elementosPorEstruturaProvider(widget.estrutura.id));
  }

  void _abrirAcoesElemento(
    BuildContext context,
    WidgetRef ref,
    ElementoModel elemento,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.edit_outlined,
                color: AppColors.textDark,
              ),
              title: const Text('Editar elemento'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ElementoFormScreen(
                      estruturaId: widget.estrutura.id,
                      projetoId: widget.projetoId,
                      elemento: elemento,
                    ),
                  ),
                );
                ref.invalidate(
                  elementosPorEstruturaProvider(widget.estrutura.id),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Excluir elemento',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmarExclusao(context, ref, elemento);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    ElementoModel elemento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir elemento'),
        content: Text('Deseja excluir "${elemento.nome ?? 'este elemento'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.greyMedium),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    try {
      await ref.read(elementoRepositoryProvider).desativarElemento(elemento.id);
      ref.invalidate(elementosPorEstruturaProvider(widget.estrutura.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elemento excluído com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
      }
    }
  }

  Widget _buildElementosList(BuildContext context, WidgetRef ref) {
    final elementosAsync = ref.watch(
      elementosPorEstruturaProvider(widget.estrutura.id),
    );

    return elementosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Erro ao carregar elementos:\n$e',
          style: const TextStyle(color: AppColors.hintText),
        ),
      ),
      data: (elementos) {
        final elementosFiltrados = _localFiltro == null
            ? elementos
            : elementos.where((el) => el.local == _localFiltro).toList();

        if (elementosFiltrados.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum elemento encontrado.',
              style: TextStyle(color: AppColors.hintText, height: 1.4),
            ),
          );
        }

        return Column(
          children: elementosFiltrados.map((el) {
            final tipo = [
              el.tipo,
              el.tipologiaEstrutural,
            ].where((p) => p != null && p.trim().isNotEmpty).join(' - ');
            final imageUrl = (el.fotos != null && el.fotos!.isNotEmpty)
                ? el.fotos!.first
                : 'assets/images/empresa.png';
            return ElementoEstruturalCard(
              titulo: el.nome ?? 'Sem nome',
              tipo: tipo.isEmpty ? 'Sem tipo' : tipo,
              local: el.local ?? 'Sem local',
              imageUrl: imageUrl,
              onTap: () => _openElemento(
                context,
                elementoId: el.id,
                titulo: el.nome ?? 'Sem nome',
                tipo: tipo,
                local: el.local ?? '',
                imageUrl: imageUrl,
                marcacaoImagemUrl: el.marcacaoImagemUrl,
              ),
              onLongPress: () => _abrirAcoesElemento(context, ref, el),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    // Assiste a mesma lista que a tela anterior de Projetos assiste.
    // Como você invalida na tela de edição, aqui é re-buscado no mesmo milésimo de segundo!
    final estruturasAsync = ref.watch(
      estruturasDoProjetoProvider(widget.projetoId),
    );

    // Procura a estrutura recém-baixada do provedor. Se der B.O e não achar, usa a inicial como fallback.
    final EstruturaModel estruturaExibida =
        estruturasAsync.value?.firstWhere(
          (e) => e.id == widget.estrutura.id,
          orElse: () => widget.estrutura,
        ) ??
        widget.estrutura;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      endDrawer: MenuDrawerAppBar(
        title: 'Menu da\nEstrutura',
        items: [
          DiaviconMenuItem(
            icon: Icons.info_outline,
            label: 'Informações',
            onTap: () async {
              Navigator.pop(context);
              // Não precisa mais do `setState` ou de esperar um retorno!
              // O Riverpod já cuida da atualização em background.
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EstruturaInformacaoScreen(
                    estrutura:
                        estruturaExibida, // Envia sempre os dados mais recentes pra edição
                    projetoId: widget.projetoId,
                  ),
                ),
              );
            },
          ),
          DiaviconMenuItem(
            icon: Icons.layers_outlined,
            label: 'Planejamento',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanejamentoPlantasScreen(
                    estruturaId: widget.estrutura.id,
                  ),
                ),
              );
            },
          ),
          DiaviconMenuItem(
            icon: Icons.science_outlined,
            label: 'Ensaios',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EstruturaEnsaiosScreen(
                    estruturaId: widget.estrutura.id,
                    projetoId: widget.projetoId,
                  ),
                ),
              );
            },
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.description_outlined,
              label: 'Relatórios',
              onTap: () {
                DiaviconAlerts.show(
                  context,
                  'Em desenvolvimento',
                  'Esta funcionalidade estará disponível em breve!',
                  isAviso: true,
                );
              },
            ),
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.pie_chart_outline,
              label: 'Dashboard',
              onTap: () {
                DiaviconAlerts.show(
                  context,
                  'Em desenvolvimento',
                  'Esta funcionalidade estará disponível em breve!',
                  isAviso: true,
                );
              },
            ),
          ),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Estrutura',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EstruturaHomeHeader(
                imageUrl: estruturaExibida.imageUrl,
                status: estruturaExibida.status ?? 'Em Andamento',
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 48 + keyboardHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estruturaExibida.nome ?? 'Sem nome',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${estruturaExibida.tipologiaNome ?? 'Sem tipologia'} - ${estruturaExibida.tipoNome ?? 'Sem tipo'}\n${estruturaExibida.idadeCalculada} Anos  CAA ${estruturaExibida.caa ?? '-'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.hintText,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 15),

                    const ProgressoProjetoCard(progresso: 0.90),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Elementos Estruturais',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        CompactButton(
                          text: 'Incluir',
                          onPressed: () => _incluirElemento(context, ref),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: SizedBox(
                            height: 36,
                            child: LocalSearchDropdown(
                              estruturaId: widget.estrutura.id,
                              value: _localFiltro,
                              onChanged: (localSelecionado) {
                                setState(() {
                                  _localFiltro = localSelecionado;
                                });
                              },
                            ),
                          ),
                        ),

                        if (_localFiltro != null) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppColors.error,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _localFiltro = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],

                        const Spacer(flex: 1),

                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () {},
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Todos',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: AppColors.textDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildElementosList(context, ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
