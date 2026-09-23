import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../models/ensaio_modelo_config.dart';
import '../models/modelo_relatorio_model.dart';
import '../providers/modelos_relatorio_provider.dart';
import 'modelo_relatorio_editor_screen.dart';

// Lista os modelos de relatório que a empresa já cadastrou para um tipo de
// ensaio específico, e permite criar/apagar modelos (só nome + descrição por
// enquanto — os campos de conteúdo do modelo entram numa próxima etapa).
class ModelosRelatorioTipoScreen extends ConsumerWidget {
  final String empresaId;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;
  final String iconePath;

  const ModelosRelatorioTipoScreen({
    super.key,
    required this.empresaId,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
    required this.iconePath,
  });

  ModelosPorTipoParams get _params => ModelosPorTipoParams(empresaId: empresaId, tipoEnsaioId: tipoEnsaioId);

  // Cada tipo de ensaio precisa do seu próprio compositor de relatório (os
  // campos/catálogos são todos específicos daquele ensaio) — ver
  // `resolverEnsaioModeloConfig`. Os tipos sem compositor ainda mostram um
  // aviso em vez de abrir o editor errado.
  bool get _compositorDisponivel => resolverEnsaioModeloConfig(tipoEnsaioNome) != null;

  // Mesma regra dos campos personalizáveis: só é editável/apagável por quem
  // o produziu — um modelo padrão (empresa_id = Diavicon) só é editável pela
  // própria Diavicon logada, nunca por outra empresa.
  bool _podeEditar(ModeloRelatorioModel modelo) => modelo.empresaId == empresaId;

  void _invalidarListas(WidgetRef ref) {
    ref.invalidate(modelosPorTipoEnsaioProvider(_params));
    ref.invalidate(resumoModelosEnsaioProvider(empresaId));
  }

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
            TextField(
              controller: nomeCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome do modelo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
            ),
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
    final dados = await _abrirDialogoNomeDescricao(context, titulo: 'Novo modelo de relatório', textoBotao: 'Criar');
    if (dados == null) return;

    try {
      final novoModelo = await ref.read(modelosRelatorioRepositoryProvider).criarModelo(
            empresaId: empresaId,
            tipoEnsaioId: tipoEnsaioId,
            nome: dados['nome']!,
            descricao: dados['descricao']!.isEmpty ? null : dados['descricao'],
          );
      _invalidarListas(ref);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModeloRelatorioEditorScreen(modeloId: novoModelo.id, tipoEnsaioNome: tipoEnsaioNome)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editarModelo(BuildContext context, WidgetRef ref, ModeloRelatorioModel modelo) async {
    final dados = await _abrirDialogoNomeDescricao(
      context,
      titulo: 'Editar modelo',
      textoBotao: 'Salvar',
      nomeInicial: modelo.nome,
      descricaoInicial: modelo.descricao,
    );
    if (dados == null) return;

    try {
      await ref.read(modelosRelatorioRepositoryProvider).atualizarInfo(
            modelo.id,
            nome: dados['nome']!,
            descricao: dados['descricao']!.isEmpty ? null : dados['descricao'],
          );
      _invalidarListas(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _duplicarModelo(BuildContext context, WidgetRef ref, ModeloRelatorioModel modelo) async {
    try {
      final copia = await ref.read(modelosRelatorioRepositoryProvider).duplicarModelo(modelo, empresaId);
      _invalidarListas(ref);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModeloRelatorioEditorScreen(modeloId: copia.id, tipoEnsaioNome: tipoEnsaioNome)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _apagarModelo(BuildContext context, WidgetRef ref, ModeloRelatorioModel modelo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar modelo'),
        content: Text('Tem certeza que deseja apagar "${modelo.nome}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await ref.read(modelosRelatorioRepositoryProvider).deletarModelo(modelo.id);
      _invalidarListas(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modelo apagado.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildCompositorIndisponivel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Modelos de relatório para "$tipoEnsaioNome" ainda não estão disponíveis.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada tipo de ensaio tem seu próprio compositor de relatório — por enquanto só Inspeção Visual está pronto.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelosAsync = ref.watch(modelosPorTipoEnsaioProvider(_params));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            const Text('Modelos de Relatórios', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text(tipoEnsaioNome, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: !_compositorDisponivel
          ? _buildCompositorIndisponivel()
          : Column(
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
                  return const Center(
                    child: Text('Nenhum modelo cadastrado ainda.', style: TextStyle(color: Colors.grey)),
                  );
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ModeloRelatorioEditorScreen(modeloId: modelo.id, tipoEnsaioNome: tipoEnsaioNome)),
                        );
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(modelo.nome,
                                            style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                      ),
                                      if (modelo.ehPadrao) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(4)),
                                          child: const Text('PADRÃO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                                        ),
                                      ],
                                    ],
                                  ),
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
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
