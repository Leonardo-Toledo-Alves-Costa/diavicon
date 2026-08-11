import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../estrutura/widgets/novo_item_dropdown_modal.dart';
import '../../estrutura/providers/estruturas_dropdown_provider.dart';

/// Widget modular que cria a caixa de seleção expansível e conecta ao backend
class BuildTabelaExpansion extends ConsumerWidget {
  final String titulo;
  final String nomeTabela;
  final AsyncValue<List<Map<String, dynamic>>> itemsAsync;

  const BuildTabelaExpansion({
    super.key,
    required this.titulo,
    required this.nomeTabela,
    required this.itemsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textDark,
        title: Text(
          titulo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // DADOS REAIS DO SUPABASE COM TRATAMENTO DE ESTADOS
          itemsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Erro ao carregar: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhum item cadastrado.',
                    style: TextStyle(color: AppColors.hintText, fontSize: 13),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lista.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, color: Color(0xFFF5F5F5)),
                itemBuilder: (context, index) {
                  final item = lista[index];
                  return ListTile(
                    title: Text(
                      item['nome'].toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BOTÃO EDITAR
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          onPressed: () => _mostrarModalEdicao(
                            context,
                            item['id'].toString(),
                            item['nome'].toString(),
                            ref,
                          ),
                        ),
                        // BOTÃO DELETAR
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmarExclusao(
                            context,
                            item['nome'].toString(),
                            item['id'].toString(),
                            ref,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // BOTÃO ADICIONAR NOVO 
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onPressed: () async {
                await showDialog<String>(
                  context: context,
                  builder: (context) => NovoItemDropdownModal(
                    titulo: titulo,
                    nomeTabela: nomeTabela,
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text(
                'Adicionar Novo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE EDIÇÃO ---
  Future<void> _mostrarModalEdicao(
    BuildContext context,
    String idItem,
    String nomeAtual,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController(text: nomeAtual);
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Editar Item',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  label: 'Nome',
                  hint: 'Novo nome...',
                  controller: controller,
                  enabled: !isLoading,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        final novoNome = controller.text.trim();
                        if (novoNome.isEmpty || novoNome == nomeAtual) {
                          Navigator.pop(context);
                          return;
                        }

                        setStateModal(() => isLoading = true);
                        try {
                          await ref
                              .read(estruturaDropdownsControllerProvider)
                              .editarItem(
                                nomeTabela: nomeTabela,
                                id: idItem,
                                novoNome: novoNome,
                              );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao editar: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          setStateModal(() => isLoading = false);
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- LÓGICA DE EXCLUSÃO ---
  Future<void> _confirmarExclusao(
    BuildContext context,
    String nomeItem,
    String idItem,
    WidgetRef ref,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir item?',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text.rich(
          TextSpan(
            text: 'Tem certeza que deseja excluir o item "',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            children: [
              TextSpan(
                text: nomeItem,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '"? Esta ação não pode ser desfeita.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await ref
            .read(estruturaDropdownsControllerProvider)
            .deletarItem(nomeTabela: nomeTabela, id: idItem);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro ao deletar: $e\nTalvez este item já esteja vinculado a uma estrutura.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}