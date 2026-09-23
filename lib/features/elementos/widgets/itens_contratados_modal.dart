import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:diavicon/features/elementos/providers/itens_contratados_provider.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/screens/ensaios_contratados_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diavicon/features/ensaios/ensaios_geral/providers/ensaios_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/compact_button.dart';

class ItensContratadosModal extends ConsumerWidget {
  final String empresaId;
  final String empresaNome;
  final String? empresaFotoUrl;
  final String estruturaId;

  const ItensContratadosModal({
    super.key,
    required this.empresaId,
    required this.empresaNome,
    this.empresaFotoUrl,
    required this.estruturaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itensAsync = ref.watch(itensContratadosProvider(estruturaId));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // seu cabeçalho continua igual...
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        (empresaFotoUrl != null && empresaFotoUrl!.isNotEmpty)
                        ? StorageNetworkImage(empresaFotoUrl!)
                        : null,
                    child: (empresaFotoUrl == null || empresaFotoUrl!.isEmpty)
                        ? const Icon(Icons.business, color: AppColors.primary)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  empresaNome,
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3E3E3D),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
                // Só mostra os ensaios que possuem contrato
                final itensContratados = itens
                    .where((item) => item.contratadas > 0)
                    .toList();

                if (itensContratados.isEmpty) {
                  return const Center(
                    child: Text('Nenhum item contratado para esta estrutura.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: itensContratados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = itensContratados[index];

                    final bool realizadasOk =
                        item.realizadas >= item.contratadas;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: Image.asset(
                              item.iconePath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.science_outlined,
                                color: AppColors.textDark,
                                size: 28,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nome,
                                  style: GoogleFonts.lato(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF3E3E3D),
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  '${item.contratadas.toString().padLeft(2, '0')} Und. contratadas',
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.greyMedium,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    // Marcadas ainda não vêm do
                                    // resumoEnsaiosProvider.
                                    _buildBadge(
                                      texto: '00 Und. marcadas',
                                      isSuccess: false,
                                    ),

                                    _buildBadge(
                                      texto:
                                          '${item.realizadas.toString().padLeft(2, '0')} Und. realizadas',
                                      isSuccess: realizadasOk,
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Center(
                child: CompactButton(
                  text: 'Gerenciar',
                  width: 160,
                  height: 50,
                  backgroundColor: AppColors.primary,
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnsaiosContratadosScreen(
                          estruturaId: estruturaId,
                          empresaId: empresaId,
                          empresaNome: empresaNome,
                          isGestora: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required String texto, required bool isSuccess}) {
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

Future<void> showItensContratadosModal(
  BuildContext context, {
  required String empresaId,
  required String empresaNome,
  String? empresaFotoUrl,
  required String estruturaId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ItensContratadosModal(
      empresaId: empresaId,
      empresaNome: empresaNome,
      empresaFotoUrl: empresaFotoUrl,
      estruturaId: estruturaId,
    ),
  );
}
