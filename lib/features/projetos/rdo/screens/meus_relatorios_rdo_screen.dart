import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:io';

import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/screens/visualizar_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/relatorio_rdo_model.dart';
import '../providers/relatorio_rdo_provider.dart';
import 'gerar_relatorio_rdo_screen.dart';
import 'selecionar_projeto_rdo_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

/// Relatórios de RDO gerados pela empresa do usuário em todos os projetos —
/// espelha `RelatorioRdoScreen` (que é escopada a um projeto), acessível
/// pelo drawer de "Meus RDOs". Gerar daqui pede o projeto primeiro, igual
/// ao "Novo RDO" de `MeusRdosScreen`.
class MeusRelatoriosRdoScreen extends ConsumerWidget {
  final String empresaId;

  const MeusRelatoriosRdoScreen({super.key, required this.empresaId});

  Future<void> _abrir(BuildContext context, RelatorioRdoModel relatorio) async {
    final url = relatorio.urlArquivo;
    if (url == null) return;

    if (relatorio.formato == 'html') {
      try {
        final resp = await StorageUrls.baixarHtml(url);
        final dir = await getApplicationDocumentsDirectory();
        final arquivo = File('${dir.path}/${relatorio.id}.html')..writeAsBytesSync(resp.bodyBytes);
        await OpenFilex.open(arquivo.path);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: AppColors.error));
        }
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VisualizarPdfScreen(url: url, titulo: relatorio.nomeRelatorio)),
    );
  }

  Future<void> _apagar(BuildContext context, WidgetRef ref, RelatorioRdoModel relatorio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar relatório'),
        content: Text('Tem certeza que deseja apagar "${relatorio.nomeRelatorio}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(relatorioRdoRepositoryProvider).deletar(relatorio.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _abrirGerarRelatorio(BuildContext context) async {
    final projeto = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelecionarProjetoRdoScreen()),
    );
    if (projeto == null || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.relatorios, child: GerarRelatorioRdoScreen(projetoId: projeto.id, projetoNome: projeto.nome, empresaId: empresaId)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relatoriosAsync = ref.watch(meusRelatoriosRdoStreamProvider(empresaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Relatórios',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Todos os projetos', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('Relatórios de RDO', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gerados', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                ElevatedButton.icon(
                  onPressed: () => _abrirGerarRelatorio(context),
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text('Gerar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            child: relatoriosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Erro ao carregar relatórios: $err', textAlign: TextAlign.center)),
              data: (relatorios) {
                if (relatorios.isEmpty) {
                  return const Center(child: Text('Nenhum relatório gerado ainda.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: relatorios.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildCard(context, ref, relatorios[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, RelatorioRdoModel relatorio) {
    final concluido = relatorio.status == 'Concluído';
    final erro = relatorio.status == 'Erro';
    final (Color corStatus, Color fundoStatus) = concluido
        ? (const Color(0xFF3AA655), const Color(0xFFDFF5E3))
        : erro
            ? (AppColors.error, const Color(0xFFFBE2E1))
            : (AppColors.primary, const Color(0xFFFCE7CC));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: concluido ? () => _abrir(context, relatorio) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relatorio.projetoNome,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(relatorio.nomeRelatorio, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  if (relatorio.data != null) ...[
                    const SizedBox(height: 2),
                    Text('RDO de ${relatorio.data}', style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: fundoStatus, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!concluido && !erro) ...[
                              SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: corStatus)),
                              const SizedBox(width: 4),
                            ],
                            Text(relatorio.status, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: corStatus)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.greyVeryLight, borderRadius: BorderRadius.circular(20)),
                        child: Text(relatorio.formato.toUpperCase(), style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.greyMedium)),
                      ),
                    ],
                  ),
                  if (erro && relatorio.erro != null) ...[
                    const SizedBox(height: 4),
                    Text(relatorio.erro!, style: GoogleFonts.lato(fontSize: 11, color: AppColors.error), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Apagar',
              onPressed: () => _apagar(context, ref, relatorio),
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
