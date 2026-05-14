import 'package:diavicon/core/widgets/diavicon_menu_item.dart';
import 'package:diavicon/core/widgets/menu_drawer_app_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../widgets/elemento_estrutural_card.dart';
import 'estrutura_informacao_screen.dart';
import '../models/estrutura_model.dart'; 

class EstruturaHomeScreen extends StatelessWidget {
  final EstruturaModel estrutura; 
  final String projetoId;

  const EstruturaHomeScreen({super.key, required this.estrutura, required this.projetoId});

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
                Navigator.pop(context); 
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EstruturaInformacaoScreen(estrutura: estrutura, projetoId: projetoId,),
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
            // 1. Imagem de Cabeçalho dinâmica
            _buildHeaderImage(),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações Principais Dinâmicas
                  Text(
                    estrutura.nome ?? 'Sem nome', 
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${estrutura.tipologiaEstrutural ?? 'Sem tipologia'} - ${estrutura.tipo ?? 'Sem tipo'}\n${estrutura.idadeAnos ?? '-'} Anos  CAA ${estrutura.caa ?? '-'}', 
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.hintText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Card de Progresso Reutilizável
                  _buildProgressCard(0.90), 
                  const SizedBox(height: 32),

                  // Seção de Título + Botão
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

                  // Filtros (Search e Dropdown)
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
                          onTap: () {},
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

                  // Lista de Cards (Mockados)
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

  // Método auxiliar: Imagem Dinâmica
  Widget _buildImage() {
    const String defaultAsset = 'assets/images/empresa.png';

    if (estrutura.imageUrl == null || estrutura.imageUrl!.isEmpty) {
      return Image.asset(defaultAsset, width: double.infinity, height: 160, fit: BoxFit.cover);
    }

    return Image.network(
      estrutura.imageUrl!,
      width: double.infinity,
      height: 160,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(defaultAsset, width: double.infinity, height: 160, fit: BoxFit.cover),
    );
  }

  // Método auxiliar: Imagem do Prédio + Badge
  Widget _buildHeaderImage() {
    return Stack(
      children: [
        _buildImage(),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              estrutura.status ?? 'Em Andamento', // <-- Status dinâmico
              style: const TextStyle(
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
        color: const Color(0xFFFFF3E0), 
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