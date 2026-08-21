import 'package:diavicon/features/elementos/providers/itens_contratados_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/compact_button.dart';
import '../../../../core/widgets/compact_search_bar.dart';
import '../../../../core/widgets/custom_appbar.dart';

class EnsaiosContratadosScreen extends ConsumerStatefulWidget {
  final String estruturaId;
  final String empresaId;
  final String empresaNome;
  final bool isGestora;

  const EnsaiosContratadosScreen({
    super.key,
    required this.estruturaId,
    required this.empresaId,
    required this.empresaNome,
    required this.isGestora,
  });

  @override
  ConsumerState<EnsaiosContratadosScreen> createState() =>
      _EnsaiosContratadosScreenState();
}

class _EnsaiosContratadosScreenState
    extends ConsumerState<EnsaiosContratadosScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final itensAsync = ref.watch(itensContratadosProvider(widget.estruturaId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Estrutura',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Ensaios',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ensaios contratados',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3E3E3D),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CompactSearchBar(
                    hintText: 'Nome do Ensaio',
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (widget.isGestora) ...[
                  const SizedBox(width: 12),
                  CompactButton(
                    text: 'Adicionar',
                    width: 100,
                    backgroundColor: AppColors.primary,
                    onPressed: () {
                      // implementar depois o modal de adicionar do banco
                    },
                  ),
                ]
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: itensAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erro ao carregar os itens contratados:\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (itens) {
                  final itensFiltrados = itens.where((item) {
                    final nome = item.nome.toLowerCase();
                    return nome.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (itensFiltrados.isEmpty) {
                    return const Center(
                      child: Text('Nenhum item contratado'),
                    );
                  }

                  return ListView.separated(
                    itemCount: itensFiltrados.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = itensFiltrados[index];
                      final completo = item.realizadas >= item.contratadas;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF2F2F2F),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  item.iconePath,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.science_outlined,
                                    size: 20,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.nome,
                                    style: GoogleFonts.lato(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF3E3E3D),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildBadge(
                                          texto:
                                              '${item.contratadas.toString().padLeft(2, '0')} Und. contratadas',
                                          isSuccess: item.contratadas > 0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildBadge(
                                        texto:
                                            '${item.realizadas.toString().padLeft(2, '0')} Und. realizadas',
                                        isSuccess: completo,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String texto,
    required bool isSuccess,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: GoogleFonts.lato(
          color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}