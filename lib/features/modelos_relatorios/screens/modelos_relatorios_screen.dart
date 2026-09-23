import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../providers/modelos_relatorio_provider.dart';
import 'modelos_relatorio_tipo_screen.dart';

// Tela geral de "Padrões da empresa > Modelos de Relatórios": lista todos os
// tipos de ensaio do sistema (mesma fonte que a tela de ensaios da estrutura)
// e mostra quantos modelos de relatório a empresa já cadastrou para cada um.
class ModelosRelatoriosScreen extends ConsumerWidget {
  final String empresaId;

  const ModelosRelatoriosScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumoAsync = ref.watch(resumoModelosEnsaioProvider(empresaId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Empresa',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          children: [
            Text('Padrões da empresa', style: TextStyle(fontSize: 12, color: Colors.white70)),
            Text('Modelos de Relatórios', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: resumoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Erro ao carregar tipos de ensaio:\n$error', textAlign: TextAlign.center),
          ),
        ),
        data: (ensaios) {
          if (ensaios.isEmpty) {
            return const Center(child: Text('Nenhum tipo de ensaio cadastrado no sistema.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24.0),
            itemCount: ensaios.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final ensaio = ensaios[index];
              final temModelos = ensaio.quantidadeModelos > 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModelosRelatorioTipoScreen(
                        empresaId: empresaId,
                        tipoEnsaioId: ensaio.tipoEnsaioId,
                        tipoEnsaioNome: ensaio.nome,
                        iconePath: ensaio.iconePath,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Image.asset(
                          ensaio.iconePath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.science_outlined, color: AppColors.textDark, size: 28);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          ensaio.nome,
                          style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: temModelos ? const Color(0xFFE8F5E9) : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${ensaio.quantidadeModelos.toString().padLeft(2, '0')} modelo${ensaio.quantidadeModelos == 1 ? '' : 's'}',
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: temModelos ? const Color(0xFF4CAF50) : AppColors.greyMedium,
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
    );
  }
}
