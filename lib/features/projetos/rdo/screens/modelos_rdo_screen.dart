import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/modelo_rdo_model.dart';
import '../providers/modelos_rdo_provider.dart';
import 'modelo_rdo_editor_screen.dart';

/// Lista os modelos de relatório de RDO que a empresa já cadastrou —
/// espelha `ModelosRelatorioTipoScreen`, sem o vínculo a `tipos_ensaio` (RDO
/// não é um tipo de ensaio, só existe um "tipo" de modelo aqui).
class ModelosRdoScreen extends ConsumerWidget {
  final String empresaId;

  const ModelosRdoScreen({super.key, required this.empresaId});

  bool _podeEditar(ModeloRdoModel modelo) => modelo.empresaId == empresaId;

  void _invalidarLista(WidgetRef ref) => ref.invalidate(modelosRdoProvider(empresaId));

  Future<Map<String, String>?> _abrirDialogoNomeDescricao(
    BuildContext context, {
    required String titulo,
    required String textoBotao,
    String? nomeInicial,
    String? descricaoInicial,
  }) async {
    final nomeCtrl = TextEditingController(text: nomeInicial);
    final descCtrl = TextEditingController(text: descricaoInicial);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nome do modelo')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(textoBotao, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true || nomeCtrl.text.trim().isEmpty) return null;
    return {'nome': nomeCtrl.text.trim(), 'descricao': descCtrl.text.trim()};
  }

  Future<void> _abrirNovoModelo(BuildContext context, WidgetRef ref) async {
    final dados = await _abrirDialogoNomeDescricao(context, titulo: 'Novo modelo de RDO', textoBotao: 'Criar');
    if (dados == null) return;

    try {
      final novoModelo = await ref.read(modelosRdoRepositoryProvider).criarModelo(
            empresaId: empresaId,
            nome: dados['nome']!,
            descricao: dados['descricao']!.isEmpty ? null : dados['descricao'],
          );
      _invalidarLista(ref);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ModeloRdoEditorScreen(modeloId: novoModelo.id)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _editarModelo(BuildContext context, WidgetRef ref, ModeloRdoModel modelo) async {
    final dados = await _abrirDialogoNomeDescricao(
      context,
      titulo: 'Editar modelo',
      textoBotao: 'Salvar',
      nomeInicial: modelo.nome,
      descricaoInicial: modelo.descricao,
    );
    if (dados == null) return;

    try {
      await ref.read(modelosRdoRepositoryProvider).atualizarInfo(
            modelo.id,
            nome: dados['nome']!,
            descricao: dados['descricao']!.isEmpty ? null : dados['descricao'],
          );
      _invalidarLista(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _duplicarModelo(BuildContext context, WidgetRef ref, ModeloRdoModel modelo) async {
    try {
      final copia = await ref.read(modelosRdoRepositoryProvider).duplicarModelo(modelo, empresaId);
      _invalidarLista(ref);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ModeloRdoEditorScreen(modeloId: copia.id)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _apagarModelo(BuildContext context, WidgetRef ref, ModeloRdoModel modelo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar modelo'),
        content: Text('Tem certeza que deseja apagar "${modelo.nome}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(modelosRdoRepositoryProvider).deletarModelo(modelo.id);
      _invalidarLista(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modelo apagado.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelosAsync = ref.watch(modelosRdoProvider(empresaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Modelos de RDO',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Modelos', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                ElevatedButton.icon(
                  onPressed: () => _abrirNovoModelo(context, ref),
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text('Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: modelosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Erro ao carregar modelos:\n$error', textAlign: TextAlign.center),
                ),
              ),
              data: (modelos) {
                if (modelos.isEmpty) {
                  return const Center(child: Text('Nenhum modelo cadastrado ainda.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: modelos.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final modelo = modelos[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ModeloRdoEditorScreen(modeloId: modelo.id)));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(modelo.nome,
                                      style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                  if (modelo.descricao?.isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(modelo.descricao!, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600])),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Duplicar',
                              onPressed: () => _duplicarModelo(context, ref, modelo),
                              icon: const Icon(Icons.copy_outlined, color: Colors.grey, size: 20),
                            ),
                            if (_podeEditar(modelo)) ...[
                              IconButton(
                                tooltip: 'Editar nome/descrição',
                                onPressed: () => _editarModelo(context, ref, modelo),
                                icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Apagar',
                                onPressed: () => _apagarModelo(context, ref, modelo),
                                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
