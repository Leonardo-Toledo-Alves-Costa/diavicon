import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/compact_search_bar.dart';
import '../providers/relatorio_ensaio_provider.dart';
import 'gerar_relatorio_screen.dart';
import 'detalhe_relatorio_screen.dart';
import 'package:diavicon/features/planos/acesso_plano.dart';

class CentralRelatoriosScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String tipoEnsaioId;
  final String tipoEnsaioNome; // 👈 CORREÇÃO: Variável adicionada
  final String projetoNome;
  final String estruturaNome;

  const CentralRelatoriosScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome, // 👈 CORREÇÃO: Exigida no construtor
    required this.projetoNome,
    required this.estruturaNome,
  });

  @override
  ConsumerState<CentralRelatoriosScreen> createState() => _CentralRelatoriosScreenState();
}

class _CentralRelatoriosScreenState extends ConsumerState<CentralRelatoriosScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final relatoriosAsync = ref.watch(relatoriosProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId, tipoEnsaioId: widget.tipoEnsaioId)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.projetoNome, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            const Text('Relatórios', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tipoEnsaioNome, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
                const SizedBox(height: 2),
                Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Central de relatórios', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => GuardaModuloPlano(modulo: ModuloPlano.relatorios, child: GerarRelatorioScreen(
                          projetoId: widget.projetoId,
                          estruturaId: widget.estruturaId,
                          tipoEnsaioId: widget.tipoEnsaioId, // 👈 CORREÇÃO: Repassando o ID para gerar o relatório
                          projetoNome: widget.projetoNome,
                          estruturaNome: widget.estruturaNome,
                        )))).then((_) => ref.refresh(relatoriosProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId, tipoEnsaioId: widget.tipoEnsaioId))));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA726),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('+ Novo Relatório', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CompactSearchBar(
                  hintText: 'Busque por nome ou local...',
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: relatoriosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
              data: (relatorios) {
                final filtrados = relatorios.where((r) {
                  final nome = r.nomeRelatorio?.toLowerCase() ?? '';
                  final locaisStr = List<String>.from(r.conteudo['locais'] ?? []).join(' ').toLowerCase();
                  return nome.contains(_searchQuery.toLowerCase()) || locaisStr.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filtrados.isEmpty) {
                  return const Center(child: Text('Nenhum relatório encontrado.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final rel = filtrados[index];
                    final locaisSelecionados = List<String>.from(rel.conteudo['locais'] ?? []);
                    final locaisStr = locaisSelecionados.isEmpty ? 'Todos os locais' : locaisSelecionados.take(3).join(', ') + (locaisSelecionados.length > 3 ? '...' : '');

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DetalheRelatorioScreen(
                          relatorio: rel,
                          tipoEnsaioNome: widget.tipoEnsaioNome,
                          projetoNome: widget.projetoNome,
                          estruturaNome: widget.estruturaNome,
                        ))).then((_) => ref.refresh(relatoriosProvider((projetoId: widget.projetoId, estruturaId: widget.estruturaId, tipoEnsaioId: widget.tipoEnsaioId))));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(rel.nomeRelatorio ?? 'Relatório', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                                  const SizedBox(height: 4),
                                  Text(locaisStr, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(height: 2),
                                  Text('Empresas: ${List<String>.from(rel.conteudo['empresas'] ?? []).join(', ')}', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade500)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(DateFormat('dd/MM/yyyy').format(rel.criadoEm), style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: rel.status == 'Aprovado' ? Colors.green.shade50 : Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(rel.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: rel.status == 'Aprovado' ? Colors.green : Colors.orange)),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.description_outlined, color: Color(0xFFFFA726), size: 40),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}