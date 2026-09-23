import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/gasto_model.dart';
import '../providers/gastos_providers.dart';
import '../repositories/gastos_repository.dart';

/// Padrões da empresa > Gastos > Categorias de gasto.
/// As categorias DIAVICON (se houver) valem para todas as empresas, somente
/// leitura. Só o admin da empresa cria, renomeia e exclui categorias.
/// Categoria com gastos lançados não pode ser excluída.
class CategoriasGastoScreen extends ConsumerWidget {
  final String empresaId;
  const CategoriasGastoScreen({super.key, required this.empresaId});

  Future<void> _editarNome(BuildContext context, WidgetRef ref, {CategoriaGastoModel? categoria}) async {
    // O controller vive dentro do próprio diálogo. Antes ele era descartado
    // logo após o `await showDialog` — mas o diálogo ainda está animando a
    // saída e o TextField ainda usa o controller nesse intervalo: "used after
    // being disposed" e o app travava ao salvar a categoria.
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => _DialogNomeCategoria(
        titulo: categoria == null ? 'Nova categoria' : 'Renomear categoria',
        nomeInicial: categoria?.nome ?? '',
      ),
    );
    final nomeLimpo = nome?.trim() ?? '';
    if (nomeLimpo.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // A tabela não tem unique: o app evita nomes repetidos.
    final existente = categoriaComNome(ref.read(categoriasGastoProvider).value ?? const [], nomeLimpo);
    if (existente != null && existente.id != categoria?.id) {
      messenger.showSnackBar(const SnackBar(content: Text('Já existe uma categoria com esse nome.')));
      return;
    }

    final repo = ref.read(gastosRepositoryProvider);
    try {
      if (categoria == null) {
        await repo.criarCategoria(empresaId: empresaId, nome: nomeLimpo);
      } else {
        await repo.renomearCategoria(categoria.id, empresaId: empresaId, nome: nomeLimpo);
      }
      ref.invalidate(categoriasGastoProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar: ${mensagemErroGastos(e)}'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _excluir(BuildContext context, WidgetRef ref, CategoriaGastoModel categoria) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(gastosRepositoryProvider).excluirCategoria(categoria.id, empresaId: empresaId);
      ref.invalidate(categoriasGastoProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Categoria excluída.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mensagemErroGastos(e)), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(ehAdminEmpresaProvider);
    final categoriasAsync = ref.watch(categoriasGastoProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Categorias de gasto',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Categorias de gasto', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      // Só o admin cadastra/renomeia/exclui; os demais apenas consultam.
      floatingActionButton: admin
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              tooltip: 'Nova categoria',
              onPressed: () => _editarNome(context, ref),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: categoriasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mensagemErroGastos(e), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => ref.invalidate(categoriasGastoProvider), child: const Text('Tentar de novo')),
              ],
            ),
          ),
        ),
        data: (todas) {
          final padrao = todas.where((c) => c.empresaId == DIAVICON_EMPRESA_ID && c.empresaId != empresaId).toList();
          final daEmpresa = todas.where((c) => c.empresaId == empresaId).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              _titulo('DA EMPRESA'),
              if (daEmpresa.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    admin ? 'Nenhuma categoria cadastrada. Toque em + para criar.' : 'Nenhuma categoria cadastrada. Peça ao admin da empresa.',
                    style: GoogleFonts.lato(fontSize: 13, color: Colors.grey),
                  ),
                ),
              for (final c in daEmpresa)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.nome, style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF3E3E3D))),
                  trailing: !admin
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (acao) {
                            if (acao == 'renomear') _editarNome(context, ref, categoria: c);
                            if (acao == 'excluir') _excluir(context, ref, c);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'renomear', child: Text('Renomear')),
                            PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                          ],
                        ),
                ),
              if (padrao.isNotEmpty) ...[
                const SizedBox(height: 20),
                _titulo('PADRÃO DIAVICON'),
                Text('Disponíveis para todas as empresas.', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                for (final c in padrao)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    title: Text(c.nome, style: GoogleFonts.lato(fontSize: 14)),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texto, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey.shade600, letterSpacing: 0.6)),
      );
}

/// Diálogo de nome da categoria, dono do próprio TextEditingController (ele
/// só é descartado quando o diálogo sai de vez da árvore, depois da animação).
class _DialogNomeCategoria extends StatefulWidget {
  final String titulo;
  final String nomeInicial;
  const _DialogNomeCategoria({required this.titulo, required this.nomeInicial});

  @override
  State<_DialogNomeCategoria> createState() => _DialogNomeCategoriaState();
}

class _DialogNomeCategoriaState extends State<_DialogNomeCategoria> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.nomeInicial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Ex.: Estacionamento'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Salvar')),
      ],
    );
  }
}
