import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../ensaios_geral/models/relatorio_ensaio_model.dart';
import '../../ensaios_geral/providers/ensaios_provider.dart';
import '../../ensaios_geral/providers/relatorio_ensaio_provider.dart';
import '../../ensaios_geral/screens/visualizar_pdf_screen.dart';
import 'gerar_relatorio_resistividade_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

// Galeria dos relatórios de Resistividade já gerados — mesmo padrão de
// `RelatorioCarbonatacaoScreen`, usando o stream genérico por estrutura (ver
// `relatoriosPorEstruturaStreamProvider`) já que Resistividade não tem o
// conceito de "inspeção geral".
class RelatorioResistividadeScreen extends ConsumerWidget {
  final String projetoId;
  final String estruturaId;
  final String projetoNome;
  final String estruturaNome;

  const RelatorioResistividadeScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.projetoNome,
    required this.estruturaNome,
  });

  Future<void> _apagar(BuildContext context, WidgetRef ref, RelatorioEnsaioModel relatorio, String tipoEnsaioId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar relatório'),
        content: Text('Tem certeza que deseja apagar "${relatorio.nomeRelatorio}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref.read(relatorioEnsaioRepositoryProvider).apagarRelatorio(relatorio.id);
      ref.invalidate(relatoriosPorEstruturaStreamProvider((estruturaId: estruturaId, tipoEnsaioId: tipoEnsaioId)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _abrir(BuildContext context, RelatorioEnsaioModel relatorio) async {
    final url = relatorio.conteudo['url_arquivo'] as String?;
    if (url == null) return;
    final formato = relatorio.conteudo['formato'] as String?;
    await _abrirArquivo(context, url: url, formato: formato, titulo: relatorio.nomeRelatorio ?? 'Relatório');
  }

  // A Tabela geral (quando ativa no modelo) é gerada como um arquivo à
  // parte, em paisagem — ver ResistividadeModeloHtmlBuilder.montarTabelaGeral.
  Future<void> _abrirTabelaGeral(BuildContext context, RelatorioEnsaioModel relatorio) async {
    final url = relatorio.conteudo['url_resumo'] as String?;
    if (url == null) return;
    final formato = relatorio.conteudo['formato'] as String?;
    await _abrirArquivo(context, url: url, formato: formato, titulo: '${relatorio.nomeRelatorio ?? 'Relatório'} - Tabela geral');
  }

  Future<void> _abrirArquivo(BuildContext context, {required String url, required String? formato, required String titulo}) async {
    if (formato == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VisualizarPdfScreen(url: url, titulo: titulo)));
      return;
    }
    try {
      final resposta = await StorageUrls.baixarHtml(url);
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/$titulo.html');
      await arquivo.writeAsBytes(resposta.bodyBytes);
      await OpenFilex.open(arquivo.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipoEnsaioIdAsync = ref.watch(buscarIdTipoEnsaioProvider('Resistividade'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Resistividade',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Resistividade', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Relatórios', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: tipoEnsaioIdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (tipoEnsaioId) {
          if (tipoEnsaioId == null) {
            return const Center(child: Text('Tipo de ensaio "Resistividade" não encontrado.'));
          }

          final relatoriosAsync = ref.watch(relatoriosPorEstruturaStreamProvider((estruturaId: estruturaId, tipoEnsaioId: tipoEnsaioId)));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Relatórios', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.relatorios, child: GerarRelatorioResistividadeScreen(
                              projetoId: projetoId,
                              estruturaId: estruturaId,
                              tipoEnsaioId: tipoEnsaioId,
                              estruturaNome: estruturaNome,
                            )),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18, color: Colors.white),
                      label: const Text('Criar relatório', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  error: (e, _) => Center(child: Text('Erro ao carregar relatórios: $e')),
                  data: (relatorios) {
                    if (relatorios.isEmpty) {
                      return const Center(child: Text('Nenhum relatório gerado ainda.', style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: relatorios.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildCard(context, ref, relatorios[index], tipoEnsaioId),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, RelatorioEnsaioModel relatorio, String tipoEnsaioId) {
    final concluido = relatorio.status == 'Concluído';
    final erro = relatorio.status == 'Erro';
    final formato = (relatorio.conteudo['formato'] as String? ?? '').toUpperCase();
    final temTabelaGeral = concluido && relatorio.conteudo['url_resumo'] != null;

    Color corStatus;
    if (concluido) {
      corStatus = const Color(0xFF4CAF50);
    } else if (erro) {
      corStatus = Colors.red;
    } else {
      corStatus = const Color(0xFFFF9800);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: concluido ? () => _abrir(context, relatorio) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(relatorio.nomeRelatorio ?? 'Relatório', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (!concluido && !erro) ...[
                        const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800))),
                        const SizedBox(width: 6),
                      ],
                      Text(relatorio.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: corStatus)),
                      if (formato.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: Text(formato, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (temTabelaGeral)
              IconButton(
                tooltip: 'Tabela geral (paisagem)',
                onPressed: () => _abrirTabelaGeral(context, relatorio),
                icon: const Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 20),
              ),
            IconButton(
              onPressed: () => _apagar(context, ref, relatorio, tipoEnsaioId),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
