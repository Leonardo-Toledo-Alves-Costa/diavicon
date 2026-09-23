import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/aviso_topo.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../estrutura/providers/estruturas_dropdown_provider.dart';
import '../../estrutura/widgets/novo_item_dropdown_modal.dart';
import '../../gastos/providers/gastos_providers.dart' show ehAdminEmpresaProvider;

/// Quantas estruturas há em cada conjunto, pela lista de ids (separados por
/// vírgula, para servir de chave estável do provider).
final _estruturasPorConjuntoProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, idsJuntos) async {
  final ids = idsJuntos.split(',').where((id) => id.isNotEmpty).toList();
  if (ids.isEmpty) return const {};
  final linhas = await Supabase.instance.client
      .from('estruturas')
      .select('conjunto_estrutural_id')
      .inFilter('conjunto_estrutural_id', ids);
  final contagem = <String, int>{};
  for (final linha in linhas as List) {
    final id = linha['conjunto_estrutural_id']?.toString();
    if (id != null) contagem[id] = (contagem[id] ?? 0) + 1;
  }
  return contagem;
});

/// Painel da empresa › Campos personalizáveis › Conjuntos estruturais.
///
/// Conjunto estrutural agrupa estruturas (um condomínio, um campus, uma
/// rodovia). Aqui se vê cada conjunto com quantas estruturas tem, e o
/// administrador cria, renomeia ou apaga — apagar só vale para conjunto vazio,
/// senão as estruturas dele ficariam sem grupo.
class ConjuntosEstruturaisScreen extends ConsumerWidget {
  const ConjuntosEstruturaisScreen({super.key});

  static const _nomeTabela = 'conjuntos_estruturais';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(ehAdminEmpresaProvider);
    final conjuntosAsync = ref.watch(conjuntosEstruturaisProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Conjuntos estruturais',
        showBackButton: true,
        showMenuButton: false,
        showNotificationButton: false,
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _criar(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Novo conjunto', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: conjuntosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Não foi possível carregar os conjuntos: $e', textAlign: TextAlign.center),
              ),
            ),
            data: (conjuntos) => _lista(context, ref, conjuntos, admin: admin),
          ),
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> conjuntos, {required bool admin}) {
    final ids = conjuntos.map((c) => c['id'].toString()).toList()..sort();
    final contagemAsync = ref.watch(_estruturasPorConjuntoProvider(ids.join(',')));
    final contagem = contagemAsync.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text(
          'Agrupam as estruturas da empresa — um condomínio, um campus, uma rodovia. '
          'Só é possível apagar um conjunto que não tenha nenhuma estrutura.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
        ),
        if (!admin) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFDF4E7), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: AppColors.textDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Só administradores da empresa criam, renomeiam ou apagam conjuntos.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textDark, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (conjuntos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.workspaces_outline, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  admin ? 'Nenhum conjunto ainda. Crie o primeiro no botão abaixo.' : 'Nenhum conjunto cadastrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          for (final c in conjuntos)
            _CartaoConjunto(
              nome: c['nome']?.toString() ?? '',
              // Enquanto a contagem não chega, não se sabe se está vazio.
              quantidade: contagem?[c['id'].toString()] ?? (contagem == null ? null : 0),
              admin: admin,
              aoEditar: () => _renomear(context, ref, c),
              aoApagar: () => _apagar(context, ref, c),
            ),
      ],
    );
  }

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final novoId = await showDialog<String>(
      context: context,
      builder: (_) => const NovoItemDropdownModal(titulo: 'Conjunto Estrutural', nomeTabela: _nomeTabela),
    );
    if (novoId == null || !context.mounted) return;
    ref.invalidate(conjuntosEstruturaisProvider);
    mostrarAviso(context, 'Conjunto criado.', tipo: TipoAviso.sucesso);
  }

  Future<void> _renomear(BuildContext context, WidgetRef ref, Map<String, dynamic> conjunto) async {
    final controle = TextEditingController(text: conjunto['nome']?.toString() ?? '');
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Renomear conjunto', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controle,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome do conjunto'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, controle.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controle.dispose();

    final nome = novoNome?.trim() ?? '';
    if (nome.isEmpty || nome == conjunto['nome']?.toString() || !context.mounted) return;

    try {
      await ref.read(estruturaDropdownsControllerProvider).editarItem(
            nomeTabela: _nomeTabela,
            id: conjunto['id'].toString(),
            novoNome: nome,
          );
      ref.invalidate(conjuntosEstruturaisProvider);
      if (context.mounted) mostrarAviso(context, 'Conjunto renomeado.', tipo: TipoAviso.sucesso);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'Não foi possível renomear: $e', tipo: TipoAviso.erro);
    }
  }

  Future<void> _apagar(BuildContext context, WidgetRef ref, Map<String, dynamic> conjunto) async {
    final id = conjunto['id'].toString();
    final nome = conjunto['nome']?.toString() ?? '';

    // Confere de novo no banco na hora de apagar: a contagem da tela pode
    // estar velha se alguém acabou de ligar uma estrutura a este conjunto.
    try {
      final algum = await Supabase.instance.client
          .from('estruturas')
          .select('id')
          .eq('conjunto_estrutural_id', id)
          .limit(1);
      if ((algum as List).isNotEmpty) {
        if (context.mounted) {
          mostrarAviso(
            context,
            'O conjunto "$nome" ainda tem estruturas. Mova-as para outro conjunto antes de apagar.',
            tipo: TipoAviso.erro,
          );
        }
        ref.invalidate(_estruturasPorConjuntoProvider);
        return;
      }
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'Não foi possível conferir o conjunto: $e', tipo: TipoAviso.erro);
      return;
    }
    if (!context.mounted) return;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apagar conjunto', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apagar o conjunto "$nome"? Ele está vazio, nenhuma estrutura é afetada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;

    try {
      await ref.read(estruturaDropdownsControllerProvider).deletarItem(nomeTabela: _nomeTabela, id: id);
      ref.invalidate(conjuntosEstruturaisProvider);
      if (context.mounted) mostrarAviso(context, 'Conjunto "$nome" apagado.', tipo: TipoAviso.sucesso);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'Não foi possível apagar: $e', tipo: TipoAviso.erro);
    }
  }
}

class _CartaoConjunto extends StatelessWidget {
  final String nome;

  /// Nulo enquanto a contagem ainda está chegando.
  final int? quantidade;
  final bool admin;
  final VoidCallback aoEditar;
  final VoidCallback aoApagar;

  const _CartaoConjunto({
    required this.nome,
    required this.quantidade,
    required this.admin,
    required this.aoEditar,
    required this.aoApagar,
  });

  @override
  Widget build(BuildContext context) {
    final vazio = quantidade == 0;
    final textoQuantidade = quantidade == null
        ? 'contando estruturas…'
        : quantidade == 1
            ? '1 estrutura'
            : '$quantidade estruturas';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Color(0xFFFDF4E7), shape: BoxShape.circle),
            child: const Icon(Icons.workspaces_outline, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(textoQuantidade, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              ],
            ),
          ),
          if (admin) ...[
            IconButton(
              tooltip: 'Renomear',
              icon: const Icon(Icons.edit_outlined, color: AppColors.textDark),
              onPressed: aoEditar,
            ),
            // Só apaga conjunto vazio; com estruturas, o botão fica apagado
            // e a dica explica o porquê.
            Tooltip(
              message: vazio
                  ? 'Apagar conjunto'
                  : 'Só é possível apagar um conjunto sem estruturas',
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: vazio ? AppColors.error : Colors.grey.shade300),
                onPressed: vazio ? aoApagar : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
