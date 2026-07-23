import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';

class SelecionarTipoEnsaioModal extends StatelessWidget {
  const SelecionarTipoEnsaioModal({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de ensaios disponíveis com os caminhos dos PNGs
    final List<Map<String, dynamic>> tiposEnsaio = [
      {'nome': 'Frente de carbonatação', 'icone': 'assets/images/ensaios/carbonatacao.png'},
      {'nome': 'Potencial de corrosão', 'icone': 'assets/images/ensaios/potencial_corrosao.png'},
      {'nome': 'Resistividade el. sup.', 'icone': 'assets/images/ensaios/resistividade.png'},
      {'nome': 'Ultrassonografia', 'icone': 'assets/images/ensaios/ultrassonografia.png'},
      {'nome': 'Prova de carga estática', 'icone': 'assets/images/ensaios/carga_estatica.png'},
      {'nome': 'Monitoramento de Fissura', 'icone': 'assets/images/ensaios/monitoramento_fissura.png'},
      {'nome': 'Esclerometria', 'icone': 'assets/images/ensaios/esclerometria.png'},
      {'nome': 'Extração de testemunho', 'icone': 'assets/images/ensaios/extracao_testemunho.png'},
      {'nome': 'Arrancamento com dinamômetro', 'icone': 'assets/images/ensaios/arrancamento.png'},
      {'nome': 'Frente de Cloretos em campo', 'icone': 'assets/images/ensaios/frente_cloretos.png'},
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // CABEÇALHO
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Espaçador para manter o texto no centro
                Text(
                  'Adicionar Ensaio',
                  style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF3E3E3D)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.greyMedium),
                ),
              ],
            ),
          ),
          
          // LISTA DE CARDS
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: tiposEnsaio.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ensaio = tiposEnsaio[index];

                return GestureDetector(
                  onTap: () {
                    // Quando clicar, fecha o modal devolvendo qual ensaio foi escolhido
                    Navigator.pop(context, ensaio);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          ensaio['icone'],
                          width: 40,
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(Icons.science_outlined, size: 32, color: AppColors.textDark),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            ensaio['nome'],
                            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}