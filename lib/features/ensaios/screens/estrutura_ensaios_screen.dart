import 'package:diavicon/features/ensaios/screens/pontos_ensaio_screen.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';

class EstruturaEnsaiosScreen extends ConsumerStatefulWidget {
  final String estruturaId;
  final String projetoId;

  const EstruturaEnsaiosScreen({
    super.key,
    required this.estruturaId,
    required this.projetoId,
  });

  @override
  ConsumerState<EstruturaEnsaiosScreen> createState() => _EstruturaEnsaiosScreenState();
}

class _EstruturaEnsaiosScreenState extends ConsumerState<EstruturaEnsaiosScreen> {
  final List<Map<String, dynamic>> _tiposEnsaio = [
    {'nome': 'Frente de carbonatação', 'contratadas': 2, 'realizadas': 2, 'imagem': 'assets/images/ensaios/carbonatacao.png'},
    {'nome': 'Potencial de corrosão', 'contratadas': 2, 'realizadas': 1, 'imagem': 'assets/images/ensaios/potencial_corrosao.png'},
    {'nome': 'Resistividade el. sup.', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/resistividade.png'},
    {'nome': 'Ultrassonografia', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/ultrassonografia.png'},
    {'nome': 'Prova de carga estática', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/carga_estatica.png'},
    {'nome': 'Monitoramento de Fissura', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/monitoramento_fissura.png'},
    {'nome': 'Esclerometria', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/esclerometria.png'},
    {'nome': 'Extração de testemunho', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/extracao_testemunho.png'},
    {'nome': 'Arrancamento com dinamômetro', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/arrancamento.png'},
    {'nome': 'Frente de Cloretos em campo', 'contratadas': 0, 'realizadas': 0, 'imagem': 'assets/images/ensaios/frente_cloretos.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: const CustomAppBar(
        title: 'Ensaios',
        showBackButton: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        itemCount: _tiposEnsaio.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final ensaio = _tiposEnsaio[index];
          final int contratadas = ensaio['contratadas'];
          final int realizadas = ensaio['realizadas'];

          Color badgeColor = Colors.transparent;
          Color badgeTextColor = Colors.transparent;
          String badgeText = '';

          if (contratadas > 0) {
            if (realizadas >= contratadas) {
              badgeColor = const Color(0xFFE8F5E9); 
              badgeTextColor = const Color(0xFF4CAF50); 
              badgeText = '${realizadas.toString().padLeft(2, '0')} Und. realizadas';
            } else if (realizadas > 0) {
              badgeColor = const Color(0xFFFFF3E0); 
              badgeTextColor = const Color(0xFFFF9800); 
              badgeText = '${realizadas.toString().padLeft(2, '0')} Und. realizadas';
            }
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PontosEnsaioScreen(
                    elementoNome: 'Visão Geral', 
                    tipoEnsaioNome: ensaio['nome'],
                    iconeEnsaio: ensaio['imagem'], 
                    projetoNome: '0233_Proj. Ensaios Estruturais', 
                    localElemento: 'Estrutura Completa', 
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
                      ensaio['imagem'], 
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, color: AppColors.textDark, size: 28),
                    ),
                  ), 
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ensaio['nome'],
                          style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${contratadas.toString().padLeft(2, '0')} Und. contratadas',
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
      ),
    );
  }
}