import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_empty_state.dart';
import '../providers/estrutura_provider.dart';
import '../providers/estruturas_dropdown_provider.dart';
import '../screens/estruturas_tab_screen.dart';

// Lista de todos os Conjuntos Estruturais da empresa, mostrada quando o
// filtro da aba Estruturas está em "Todos". Tocar num conjunto "abre" ele
// (mesmo state provider do filtro, ver estruturas_tab_screen.dart). Um
// conjunto só pode ser excluído se não tiver nenhuma estrutura vinculada.
class ConjuntosEstruturaisList extends ConsumerWidget {
  const ConjuntosEstruturaisList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);
    final estruturasAsync = ref.watch(todasEstruturasDaMinhaEmpresaProvider);

    return conjuntosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (err, _) => Center(child: Text('Erro: $err')),
      data: (conjuntos) {
        if (conjuntos.isEmpty) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [CustomEmptyState(text: 'Nenhum conjunto estrutural cadastrado'), SizedBox(height: 80)],
          );
        }

        final contagemPorConjunto = <String, int>{};
        estruturasAsync.whenData((estruturas) {
          for (final e in estruturas) {
            final id = e.conjuntoEstruturalId;
            if (id == null) continue;
            contagemPorConjunto[id] = (contagemPorConjunto[id] ?? 0) + 1;
          }
        });
        final carregandoContagem = estruturasAsync.isLoading;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: conjuntos.length,
          itemBuilder: (context, index) {
            final conjunto = conjuntos[index];
            final id = conjunto['id'].toString();
            final nome = conjunto['nome']?.toString() ?? 'Sem nome';
            final qtd = contagemPorConjunto[id] ?? 0;
            final vazio = !carregandoContagem && qtd == 0;

            return _ConjuntoEstruturalTile(
              nome: nome,
              qtdEstruturas: qtd,
              carregandoContagem: carregandoContagem,
              podeExcluir: vazio,
              onAbrir: () => ref.read(estruturaConjuntoFiltroProvider.notifier).state = id,
              onExcluir: () => _confirmarExclusao(context, ref, id: id, nome: nome),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, WidgetRef ref, {required String id, required String nome}) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir conjunto estrutural?'),
        content: Text('O conjunto "$nome" será excluído permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(estruturaDropdownsControllerProvider).deletarItem(nomeTabela: 'conjuntos_estruturais', id: id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conjunto estrutural excluído.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível excluir: $e')));
      }
    }
  }
}

class _ConjuntoEstruturalTile extends StatelessWidget {
  final String nome;
  final int qtdEstruturas;
  final bool carregandoContagem;
  final bool podeExcluir;
  final VoidCallback onAbrir;
  final VoidCallback onExcluir;

  const _ConjuntoEstruturalTile({
    required this.nome,
    required this.qtdEstruturas,
    required this.carregandoContagem,
    required this.podeExcluir,
    required this.onAbrir,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        onTap: onAbrir,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    Text(
                      carregandoContagem ? 'Carregando...' : (qtdEstruturas == 1 ? '1 estrutura' : '$qtdEstruturas estruturas'),
                      style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: podeExcluir ? 'Excluir conjunto' : 'Só é possível excluir um conjunto vazio',
                onPressed: podeExcluir ? onExcluir : null,
                icon: Icon(Icons.delete_outline, color: podeExcluir ? AppColors.error : AppColors.greyLight),
              ),
              const Icon(Icons.keyboard_arrow_right, color: AppColors.hintText),
            ],
          ),
        ),
      ),
    );
  }
}
