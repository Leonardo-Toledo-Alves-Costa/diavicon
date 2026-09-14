import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/ensaio_resumo_model.dart';
import '../providers/ensaios_provider.dart';
import 'pontos_ensaio_screen.dart';
import '../../ensaios_inspecao_visual/screens/inspecao_visual_lista_screen.dart';



class EstruturaEnsaiosScreen extends ConsumerWidget {
  final String estruturaId;
  final String projetoId;
  final String projetoNome; 
  final String estruturaNome;

  const EstruturaEnsaiosScreen({
    super.key,
    required this.estruturaId,
    required this.projetoId,
    this.projetoNome = 'Projeto',
    this.estruturaNome = 'Estrutura',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👈 Busca todos os ensaios da estrutura sem filtrar pelo ID específico
    final AsyncValue<List<ResumoEnsaioModel>> ensaiosAsync = ref.watch(
      resumoEnsaiosProvider(ResumoEnsaiosParams(
        projetoId: projetoId,
        estruturaId: estruturaId,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Ensaios',
        showBackButton: true,
        showMenuButton: false,
      ),
      body: ensaiosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Erro ao carregar ensaios:\n$error', textAlign: TextAlign.center),
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

              Color badgeColor = Colors.transparent;
              Color badgeTextColor = Colors.transparent;
              String badgeText = '';

              if (ensaio.realizadas > 0) {
                if (ensaio.realizadas >= ensaio.contratadas) {
                  badgeColor = const Color(0xFFE8F5E9);
                  badgeTextColor = const Color(0xFF4CAF50);
                  badgeText = '${ensaio.realizadas.toString().padLeft(2, '0')} Und. realizadas';
                } else if (ensaio.realizadas > 0) {
                  badgeColor = const Color(0xFFFFF3E0);
                  badgeTextColor = const Color(0xFFFF9800);
                  badgeText = '${ensaio.realizadas.toString().padLeft(2, '0')} Und. realizadas';
                }
              }

              return GestureDetector(
                onTap: () {
                  // 🌟 A LÓGICA DE ROTEAMENTO DINÂMICO ENTRA AQUI 🌟
                  final nomeEnsaioLower = ensaio.nome.toLowerCase();
                  
                  if (nomeEnsaioLower.contains('inspeção visual') || nomeEnsaioLower.contains('inspecao visual')) {
                    // Rota para o módulo de Inspeção Visual
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InspecaoVisualListaScreen(
                          projetoId: projetoId,
                          projetoNome: projetoNome,
                          estruturaNome: estruturaNome,
                          estruturaId: estruturaId,
                          iconeEnsaio: ensaio.iconePath,
                          
                        ),
                      ),
                    );
                  } else {
                    // Rota padrão para ensaios regulares (Potencial, Resistividade, etc)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PontosEnsaioScreen(
                          projetoId: projetoId,
                          estruturaId: estruturaId,
                          tipoEnsaioId: ensaio.id, // Pega o ID (UUID) da tabela tipos_ensaio
                          iconeEnsaio: ensaio.iconePath,
                        ),
                      ),
                    );
                  }
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ensaio.nome,
                              style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${ensaio.contratadas.toString().padLeft(2, '0')} Und. contratadas',
                                  style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium),
                                ),
                                if (badgeText.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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