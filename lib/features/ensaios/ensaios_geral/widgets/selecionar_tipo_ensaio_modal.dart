import 'package:diavicon/features/ensaios/ensaios_geral/providers/ensaios_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

class SelecionarTipoEnsaioModal extends ConsumerWidget {
  const SelecionarTipoEnsaioModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiposAsync = ref.watch(tiposEnsaioProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  'Adicionar Ensaio',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF3E3E3D),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.greyMedium),
                ),
              ],
            ),
          ),
          Expanded(
            child: tiposAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, stack) => Center(
                child: Text('Erro ao carregar ensaios: $err'),
              ),
              data: (tiposEnsaio) {
                if (tiposEnsaio.isEmpty) {
                  return const Center(
                    child: Text('Nenhum tipo de ensaio cadastrado'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: tiposEnsaio.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ensaio = tiposEnsaio[index];
                    final icone = ensaio['icone']?.toString() ?? '';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context, ensaio);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            if (icone.startsWith('http'))
                              Image.network(
                                icone,
                                width: 40,
                                height: 40,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.science_outlined, size: 32),
                              )
                            else
                              Image.asset(
                                icone,
                                width: 40,
                                height: 40,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.science_outlined, size: 32),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                ensaio['nome'],
                                style: GoogleFonts.lato(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3E3E3D),
                                ),
                              ),
                            ),
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