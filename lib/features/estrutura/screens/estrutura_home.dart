import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../widgets/elemento_estrutural_card.dart';
import 'estrutura_informacao_screen.dart';

class EstruturaHomeScreen extends StatelessWidget {
  const EstruturaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: MenuDrawerAppBar(
        title: 'Menu da\nEstrutura',
        items: [
          DiaviconMenuItem(
              icon: Icons.info_outline,
              label: 'Informações',
              onTap: () {
                // 1. Fecha o menu lateral PRIMEIRO, liberando o foco
                Navigator.pop(context); 
                
                // 2. Depois abre a tela de Informações tranquilamente
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EstruturaInformacaoScreen(),
                  ),
                );
              },
            ),
          DiaviconMenuItem(
            icon: Icons.layers_outlined,
            label: 'Planejamento',
            onTap: () {},
          ),
          DiaviconMenuItem(
            icon: Icons.science_outlined,
            label: 'Ensaios',
            onTap: () {},
          ),
          DiaviconMenuItem(
            icon: Icons.description_outlined,
            label: 'Relatórios',
            onTap: () {},
          ),
          DiaviconMenuItem(
            icon: Icons.pie_chart_outline,
            label: 'Dashboard',
            onTap: () {},
          ),
        ],
      ),
      appBar: const CustomAppBar(title: 'Estrutura', showBackButton: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Imagem de Cabeçalho com o selo "Em Andamento"
            _buildHeaderImage(),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Informações Principais
                  const Text(
                    'Edf. Ouro Negro Res.',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Edifício - Concreto Armado\n25 Anos CAA II',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.hintText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Card de Progresso Reutilizável
                  _buildProgressCard(0.90), // 90%
                  const SizedBox(height: 32),

                  // 4. Seção de Título + Botão
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Elementos Estruturais',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      CompactButton(
                        text: 'Incluir',
                        onPressed: () {
                          // TODO: Abrir modal de inclusão de elementos
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. Filtros (Search e Dropdown)
                  Row(
                    children: [
                      const Expanded(
                        flex: 5,
                        child: CompactSearchBar(hintText: 'Local'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Abrir filtro de "Todos"
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Todos',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.textDark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 6. Lista de Cards (Mockados como no Figma)
                  const ElementoEstruturalCard(
                    titulo: 'V201',
                    tipo: 'Viga - Concreto armado',
                    local: 'Casa de máquinas',
                    imageUrl: 'assets/images/empresa.png',
                  ),
                  const ElementoEstruturalCard(
                    titulo: 'P102',
                    tipo: 'Pilar - Concreto armado',
                    local: '1º Subsolo',
                    imageUrl: 'assets/images/empresa.png',
                  ),
                  const ElementoEstruturalCard(
                    titulo: 'P105',
                    tipo: 'Pilar - Concreto armado',
                    local: '3º Andar',
                    imageUrl: 'assets/images/empresa.png',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método auxiliar: Imagem do Prédio
  Widget _buildHeaderImage() {
    return Stack(
      children: [
        Image.asset(
          'assets/images/empresa.png', // Lembre-se de colocar a imagem correta do prédio aqui depois
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Em Andamento',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Método auxiliar: Card de Progresso
  Widget _buildProgressCard(double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Laranja clarinho
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progresso no projeto',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: const Color(0xFFE0E0E0),
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
