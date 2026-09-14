import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/campos_personalizaveis_provider.dart';
import '../providers/sistema_provider.dart';

class CampoItensScreen extends ConsumerWidget {
  final String empresaId;
  final String tableName;
  final String displayTitle;

  const CampoItensScreen({
    super.key,
    required this.empresaId,
    required this.tableName,
    required this.displayTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (tabela: tableName, empresaId: empresaId);
    final listAsync = ref.watch(camposListProvider(params));
    
    final currentFilter = ref.watch(campoFilterProvider);
    final currentSistemaFilter = ref.watch(sistemaFilterProvider); // Ouve o filtro de sistema

    // Carrega a lista de sistemas para preencher o Dropdown (caso seja a tabela tipos_elemento)
    final sistemasListAsync = tableName == 'tipos_elemento' ? ref.watch(sistemasDropdownProvider(empresaId)) : null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            const Text('Empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Text('Painel', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text(displayTitle, style: const TextStyle(fontSize: 14, color: Colors.white)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // TÍTULO E BOTÃO NOVO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(displayTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () => _abrirModalFormulario(context, ref, null),
                  child: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // BUSCA E FILTRO PADRÃO
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    onChanged: (val) => ref.read(campoSearchProvider.notifier).setBusca(val),
                    decoration: InputDecoration(
                      hintText: 'buscar item',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: currentFilter,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                    decoration: const InputDecoration(border: InputBorder.none),
                    items: ['Todos', 'Padrão', 'Criados'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) ref.read(campoFilterProvider.notifier).setFiltro(val);
                    },
                  ),
                ),
              ],
            ),

            // ========================================================
            // NOVO: FILTRO EXCLUSIVO PARA "TIPOS DE ELEMENTO"
            // ========================================================
            if (tableName == 'tipos_elemento' && sistemasListAsync != null) ...[
              const SizedBox(height: 12),
              sistemasListAsync.when(
                loading: () => const LinearProgressIndicator(color: AppColors.primary),
                error: (e, _) => Text('Erro ao carregar sistemas: $e', style: const TextStyle(color: Colors.red)),
                data: (sistemas) {
                  return DropdownButtonFormField<String?>(
                    value: currentSistemaFilter,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por sistema habitacional',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Colors.black12)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Todos os sistemas', style: TextStyle(fontSize: 14))),
                      ...sistemas.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.nome, style: const TextStyle(fontSize: 14)))),
                    ],
                    onChanged: (val) {
                      ref.read(sistemaFilterProvider.notifier).setFiltro(val);
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 20),

            // LISTAGEM DOS ITENS
            Expanded(
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.red))),
                data: (itens) {
                  if (itens.isEmpty) {
                    return const Center(child: Text('Nenhum registro encontrado.', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: itens.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      final isPadrao = item.isPadrao();
                      final podeEditar = item.canEdit(empresaId); 

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.nome, 
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isPadrao) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                          child: const Text('Padrão', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                                        )
                                      ]
                                    ],
                                  ),
                                  if (item.descricao != null && item.descricao!.trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        item.descricao!, 
                                        maxLines: 2, 
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3), 
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isPadrao)
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, color: Colors.blueGrey, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _abrirModalVisualizacao(context, item),
                              ),
                            if (podeEditar) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _abrirModalFormulario(context, ref, item),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmarDelecao(context, ref, item),
                              ),
                            ]
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalVisualizacao(BuildContext context, CampoItemModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(item.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(onTap: () => Navigator.pop(dialogContext), child: const Icon(Icons.close, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                  child: const Text('Padrão', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                const Text('Descrição:', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  item.descricao != null && item.descricao!.trim().isNotEmpty ? item.descricao! : 'Nenhuma descrição informada.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Fechar', style: TextStyle(color: Colors.black87)),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  void _abrirModalFormulario(BuildContext context, WidgetRef outerRef, CampoItemModel? itemAtual) {
    final nomeCtrl = TextEditingController(text: itemAtual?.nome ?? '');
    final descCtrl = TextEditingController(text: itemAtual?.descricao ?? '');
    String? sistemaSelecionadoId = itemAtual?.sistemaId;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final sistemasAsync = tableName == 'tipos_elemento' 
                ? ref.watch(sistemasDropdownProvider(empresaId)) 
                : null;

            return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(itemAtual == null ? 'Novo item' : 'Editar item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            GestureDetector(onTap: () => Navigator.pop(dialogContext), child: const Icon(Icons.close, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Nome', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: nomeCtrl,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),

                        // DROPDOWN CONDICIONAL NO MODAL DE CADASTRO/EDIÇÃO (tipos_elemento)
                        if (tableName == 'tipos_elemento') ...[
                          const SizedBox(height: 16),
                          const Text('Sistema pertencente', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          sistemasAsync != null
                              ? sistemasAsync.when(
                                  loading: () => const LinearProgressIndicator(color: AppColors.primary),
                                  error: (e, _) => Text('Erro ao carregar sistemas: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                  data: (sistemas) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        value: sistemas.any((s) => s.id == sistemaSelecionadoId) ? sistemaSelecionadoId : null,
                                        isExpanded: true,
                                        decoration: const InputDecoration(border: InputBorder.none),
                                        hint: const Text('Selecione o sistema', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                        items: sistemas.map((sistema) {
                                          return DropdownMenuItem<String>(
                                            value: sistema.id,
                                            child: Text(sistema.nome, style: const TextStyle(fontSize: 14)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() => sistemaSelecionadoId = val);
                                        },
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ],

                        const SizedBox(height: 16),
                        const Text('Descrição', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: descCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF9F9F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black26),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => Navigator.pop(dialogContext),
                                child: const Text('Cancelar', style: TextStyle(color: Colors.black87)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E2E2E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: isSaving ? null : () async {
                                  if (nomeCtrl.text.trim().isEmpty) return;
                                  
                                  setState(() => isSaving = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(dialogContext);

                                  try {
                                    final Map<String, dynamic> dados = {
                                      'nome': nomeCtrl.text.trim(),
                                      'empresa_id': empresaId,
                                    };
                                    
                                    if (descCtrl.text.trim().isNotEmpty) {
                                      dados['descricao'] = descCtrl.text.trim();
                                    } else {
                                      dados['descricao'] = '';
                                    }

                                    if (tableName == 'tipos_elemento') {
                                      dados['sistemas_id'] = sistemaSelecionadoId;
                                    }

                                    if (itemAtual == null) {
                                      await Supabase.instance.client.from(tableName).insert(dados);
                                    } else {
                                      await Supabase.instance.client.from(tableName).update(dados).eq('id', itemAtual.id);
                                    }
                                    
                                    outerRef.invalidate(camposListProvider((tabela: tableName, empresaId: empresaId)));
                                    navigator.pop();
                                    messenger.showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
                                  } on PostgrestException catch (e) {
                                    messenger.showSnackBar(SnackBar(content: Text('Erro: ${e.message}'), backgroundColor: Colors.red));
                                    setState(() => isSaving = false);
                                  } on AuthException catch (e) {
                                    messenger.showSnackBar(SnackBar(content: Text('Erro: ${e.message}'), backgroundColor: Colors.red));
                                    setState(() => isSaving = false);
                                  } catch (e) {
                                    messenger.showSnackBar(SnackBar(content: Text('Erro inesperado: $e'), backgroundColor: Colors.red));
                                    setState(() => isSaving = false);
                                  }
                                },
                                child: isSaving 
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  void _confirmarDelecao(BuildContext context, WidgetRef ref, CampoItemModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Excluir item?'),
          content: Text('Deseja realmente apagar "${item.nome}"? Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);
                
                try {
                  await Supabase.instance.client.from(tableName).delete().eq('id', item.id);
                  ref.invalidate(camposListProvider((tabela: tableName, empresaId: empresaId)));
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Item apagado com sucesso.'), backgroundColor: Colors.green));
                } on PostgrestException catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.message}'), backgroundColor: Colors.red));
                } on AuthException catch (e) {
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.message}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Excluir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }
}