import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/custom_appbar.dart';
import '../models/relatorio_ensaio_model.dart';
import '../providers/relatorio_ensaio_provider.dart';

// 👇 NOVO IMPORT DA TELA DE PDF (ajuste o caminho se necessário)
import 'visualizar_pdf_screen.dart'; 

class DetalheRelatorioScreen extends ConsumerStatefulWidget {
  final RelatorioEnsaioModel relatorio;
  final String tipoEnsaioNome;
  final String projetoNome;
  final String estruturaNome;

  const DetalheRelatorioScreen({
    super.key, required this.relatorio, required this.tipoEnsaioNome, required this.projetoNome, required this.estruturaNome,
  });

  @override
  ConsumerState<DetalheRelatorioScreen> createState() => _DetalheRelatorioScreenState();
}

class _DetalheRelatorioScreenState extends ConsumerState<DetalheRelatorioScreen> {
  Future<void> _apagarRelatorio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apagar Relatório'),
        content: const Text('Tem certeza que deseja apagar este relatório definitivamente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Apagar', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmar == true) {
      try {
        await ref.read(relatorioEnsaioRepositoryProvider).apagarRelatorio(widget.relatorio.id);
        if (mounted) {
          Navigator.pop(context); // Volta pra lista
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relatório apagado.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> config = widget.relatorio.conteudo;
    final List<String> locais = List<String>.from(config['locais'] ?? []);
    final List<String> tipos = List<String>.from(config['tipos_elemento'] ?? []);
    
    String dataInicioStr = config['data_inicio'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(config['data_inicio'])) : 'Todo o período';
    String dataFimStr = config['data_fim'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(config['data_fim'])) : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const CustomAppBar(
        title: 'Relatórios',
        showBackButton: true,
        titleWidget: Text('Ensaio', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tipoEnsaioNome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
            const SizedBox(height: 2),
            Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
            Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
            const SizedBox(height: 24),

            Row(
              children: [
                const Icon(Icons.description_outlined, color: Color(0xFF3E3E3D), size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.relatorio.nomeRelatorio ?? 'Relatório', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(DateFormat('dd/MM/yyyy').format(widget.relatorio.criadoEm), style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.relatorio.status, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20)
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // 👇 BOTÃO DE VISUALIZAR ATUALIZADO
                ElevatedButton.icon(
                  onPressed: () {
                    // Extrai a URL: busca pela propriedade 'anexo' do model ou dentro do config (JSON 'conteudo')
                    final String? urlPdf = config['url_pdf']; // Substitua por widget.relatorio.anexo se a URL estiver mapeada lá
                    
                    if (urlPdf != null && urlPdf.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VisualizarPdfScreen(
                            url: urlPdf,
                            titulo: widget.relatorio.nomeRelatorio ?? 'Relatório',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('O PDF ainda não foi gerado ou o arquivo não foi encontrado.'),
                          backgroundColor: Colors.orange,
                        )
                      );
                    }
                  },
                  icon: const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                  label: const Text('Visualizar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),

            const Text('Descrição (Filtros Utilizados)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Período de análise considerado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(dataFimStr.isEmpty ? dataInicioStr : '$dataInicioStr a $dataFimStr', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 24),
                  
                  const Text('Locais', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(locais.isEmpty ? 'Todos os locais selecionados' : locais.join(', '), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 24),

                  const Text('Tipos de elementos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(tipos.isEmpty ? 'Todos os tipos selecionados' : tipos.join(', '), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            Center(
              child: OutlinedButton(
                onPressed: _apagarRelatorio,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12)
                ),
                child: const Text('Apagar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}