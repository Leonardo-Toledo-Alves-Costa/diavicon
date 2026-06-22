import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';

import '../../elementos/models/elemento_model.dart';
import '../../elementos/providers/elemento_provider.dart';
import '../../elementos/screens/elementos_screen.dart' show ElementoFormScreen;
import '../../elementos/screens/planejamento_plantas_screen.dart';
import '../../elementos/widgets/incluir_elemento_estrutural_sheet.dart';
import '../models/estrutura_model.dart';
import '../widgets/elemento_estrutural_card.dart';
import '../widgets/estrutura_home_header.dart';
import '../widgets/progresso_projeto_card.dart';
import 'estrutura_informacao_screen.dart';

class EstruturaHomeScreen extends ConsumerWidget {
  final EstruturaModel estrutura;
  final String projetoId;

  const EstruturaHomeScreen({super.key, required this.estrutura, required this.projetoId});

  void _openElemento(
    BuildContext context, {
    required String elementoId,
    required String titulo,
    required String tipo,
    required String local,
    required String imageUrl,
  }) {
    context.push(
      '/estruturas/${estrutura.id}/elementos/$elementoId',
      extra: <String, dynamic>{
        'projetoId': projetoId,
        'estruturaId': estrutura.id,
        'elementoId': elementoId,
        'titulo': titulo,
        'tipo': tipo,
        'local': local,
        'imageUrl': imageUrl,
      },
    );
  }

  /// Abre a folha de inclusão de elementos da estrutura atual.
  Future<void> _incluirElemento(BuildContext context, WidgetRef ref) async {
    await showIncluirElementoEstruturalSheet<void>(
      context: context,
      estruturaId: estrutura.id,
    );
    ref.invalidate(elementosPorEstruturaProvider(estrutura.id));
  }

  /// Menu de ações (editar/excluir) ao manter o card pressionado.
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
              leading: const Icon(Icons.edit_outlined, color: AppColors.textDark),
              title: const Text('Editar elemento'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ElementoFormScreen(
                      estruturaId: estrutura.id,
                      elemento: elemento,
                    ),
                  ),
                );
                ref.invalidate(elementosPorEstruturaProvider(estrutura.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Excluir elemento',
                  style: TextStyle(color: AppColors.error)),
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
            child: const Text('Cancelar', style: TextStyle(color: AppColors.greyMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    try {
      await ref.read(elementoRepositoryProvider).desativarElemento(elemento.id);
      ref.invalidate(elementosPorEstruturaProvider(estrutura.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elemento excluído com sucesso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  /// Lista de elementos reais da estrutura, com estados de carregamento.
  Widget _buildElementosList(BuildContext context, WidgetRef ref) {
    final elementosAsync =
        ref.watch(elementosPorEstruturaProvider(estrutura.id));

    return elementosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Erro ao carregar elementos:\n$e',
            style: const TextStyle(color: AppColors.hintText)),
      ),
      data: (elementos) {
        if (elementos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Nenhum elemento cadastrado ainda.\nToque em "Incluir" para adicionar.',
              style: TextStyle(color: AppColors.hintText, height: 1.4),
            ),
          );
        }

        return Column(
          children: elementos.map((el) {
            final tipo = [el.tipo, el.revestimento]
                .where((p) => p != null && p.trim().isNotEmpty)
                .join(' - ');
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
              ),
              onLongPress: () => _abrirAcoesElemento(context, ref, el),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, 
      endDrawer: MenuDrawerAppBar(
        title: 'Menu da\nEstrutura',
        items: [
          DiaviconMenuItem(
              icon: Icons.info_outline,
              label: 'Informações',
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => EstruturaInformacaoScreen(estrutura: estrutura, projetoId: projetoId)));
              },
            ),
          DiaviconMenuItem(
            icon: Icons.layers_outlined,
            label: 'Planejamento',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) =>  PlanejamentoPlantasScreen(estruturaId: estrutura.id)),
              );
            },
          ),
          DiaviconMenuItem(icon: Icons.science_outlined, label: 'Ensaios', onTap: () {}),
          DiaviconMenuItem(icon: Icons.description_outlined, label: 'Relatórios', onTap: () {}),
          DiaviconMenuItem(icon: Icons.pie_chart_outline, label: 'Dashboard', onTap: () {}),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Estrutura', 
        showBackButton: true, 
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            const Text('Estrutura', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // O NOVO WIDGET DE CABEÇALHO AQUI
            EstruturaHomeHeader(
              imageUrl: estrutura.imageUrl,
              status: estrutura.status ?? 'Em Andamento',
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(estrutura.nome ?? 'Sem nome', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('${estrutura.tipologiaNome ?? 'Sem tipologia'} - ${estrutura.tipoNome ?? 'Sem tipo'}\n${estrutura.idadeCalculada} Anos  CAA ${estrutura.caa ?? '-'}', style: const TextStyle(fontSize: 14, color: AppColors.hintText, height: 1.4)),
                  const SizedBox(height: 24),

                  // O NOVO WIDGET DE PROGRESSO AQUI
                  const ProgressoProjetoCard(progresso: 0.90), 
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Elementos Estruturais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      CompactButton(text: 'Incluir', onPressed: () => _incluirElemento(context, ref)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Expanded(flex: 5, child: CompactSearchBar(hintText: 'Local')),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () {},
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Todos', style: TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                              SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
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
    );
  }
}
