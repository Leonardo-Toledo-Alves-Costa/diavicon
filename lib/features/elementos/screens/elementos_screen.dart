import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/elemento_model.dart';
import '../providers/elemento_provider.dart';

// 🔥 Imports novos para permissões e para a nova tela de formulário separada
import '../../projetos/providers/projetos_provider.dart';
import 'elemento_form_screen.dart';

/// Tela de listagem dos elementos estruturais de uma estrutura.
/// Rota: /estruturas/:estruturaId/elementos
class ElementosScreen extends ConsumerWidget {
  final String estruturaId;
  final String estruturaNome;
  final String projetoId; // 🔥 Adicionado para validar permissões

  const ElementosScreen({
    super.key,
    required this.estruturaId,
    required this.estruturaNome,
    required this.projetoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elementosAsync = ref.watch(elementosPorEstruturaProvider(estruturaId));

    // 🔥 Lógica de Permissão: Verifica se a empresa logada é a gestora do projeto
    final projetoAsync = ref.watch(projectDetailProvider(projetoId));
    final usuarioEmpresaIdAsync = ref.watch(loggedUserCompanyIdProvider);
    
    bool canEdit = false;
    projetoAsync.whenData((projeto) {
      usuarioEmpresaIdAsync.whenData((empresaId) {
        canEdit = (projeto.empresaGestoraId == empresaId);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elementos Estruturais',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            Text(
              estruturaNome,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.greyMedium,
              ),
            ),
          ],
        ),
      ),
      body: elementosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar elementos:\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.greyMedium),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => ref.invalidate(elementosPorEstruturaProvider(estruturaId)),
                child: const Text('Tentar novamente', style: TextStyle(color: AppColors.white)),
              ),
            ],
          ),
        ),
        data: (elementos) => elementos.isEmpty
            ? _buildVazio(context, canEdit)
            : _buildLista(context, ref, elementos, canEdit),
      ),

      // ── FAB: Novo elemento ─────────────────────────────────────────────────
      // 🔥 O botão de Novo Elemento só aparece se o usuário tiver permissão
      floatingActionButton: canEdit 
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: AppColors.white),
              label: const Text(
                'Novo Elemento',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _abrirForm(context, ref, null),
            )
          : null,
    );
  }

  // ── Estado vazio ───────────────────────────────────────────────────────────
  Widget _buildVazio(BuildContext context, bool canEdit) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.foundation, size: 72, color: AppColors.greyLight),
          const SizedBox(height: 16),
          const Text(
            'Nenhum elemento cadastrado',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.greyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canEdit ? 'Toque em "Novo Elemento" para começar' : 'Esta estrutura ainda não possui elementos.',
            style: const TextStyle(fontSize: 13, color: AppColors.greyLight),
          ),
        ],
      ),
    );
  }

  // ── Lista de elementos ─────────────────────────────────────────────────────
  Widget _buildLista(
    BuildContext context,
    WidgetRef ref,
    List<ElementoModel> elementos,
    bool canEdit,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: elementos.length,
      itemBuilder: (context, index) {
        final el = elementos[index];
        return _ElementoCard(
          elemento: el,
          canEdit: canEdit, // 🔥 Passa a permissão para o card
          onEditar: () => _abrirForm(context, ref, el),
          onDeletar: () => _confirmarDelete(context, ref, el),
        );
      },
    );
  }

  // ── Abrir formulário ───────────────────────────────────────────────────────
  void _abrirForm(BuildContext context, WidgetRef ref, ElementoModel? elemento) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ElementoFormScreen(
          estruturaId: estruturaId,
          projetoId: projetoId, // 🔥 Passa o projetoId para a tela de form
          elemento: elemento,
          onSalvo: () => ref.invalidate(elementosPorEstruturaProvider(estruturaId)),
        ),
      ),
    );
  }

  // ── Confirmar exclusão ─────────────────────────────────────────────────────
  Future<void> _confirmarDelete(
    BuildContext context,
    WidgetRef ref,
    ElementoModel elemento,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir elemento'),
        content: Text('Deseja excluir "${elemento.nome}"? Esta ação não pode ser desfeita.'),
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

    if (confirmar == true && context.mounted) {
      try {
        await ref.read(elementoRepositoryProvider).desativarElemento(elemento.id);
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
  }
}

// ─── Card do elemento ─────────────────────────────────────────────────────────
class _ElementoCard extends StatelessWidget {
  final ElementoModel elemento;
  final bool canEdit; // 🔥 Adicionado controle no card
  final VoidCallback onEditar;
  final VoidCallback onDeletar;

  const _ElementoCard({
    required this.elemento,
    required this.canEdit,
    required this.onEditar,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // Ajustado .withValues(alpha) para withOpacity
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: const Icon(Icons.foundation, color: AppColors.primary),
        ),
        title: Text(
          elemento.nome ?? 'Sem nome',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (elemento.tipo != null)
              Text(
                elemento.tipo!,
                style: const TextStyle(fontSize: 12, color: AppColors.greyMedium),
              ),
            if (elemento.tipologiaEstrutural != null)
              Text(
                elemento.tipologiaEstrutural!,
                style: const TextStyle(fontSize: 12, color: AppColors.greyMedium),
              ),
          ],
        ),
        // 🔥 Esconde o botão de opções se não puder editar
        trailing: canEdit
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.greyMedium),
                onSelected: (val) {
                  if (val == 'editar') onEditar();
                  if (val == 'deletar') onDeletar();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: AppColors.textDark),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'deletar',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Excluir', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}