import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_appbar.dart';
import '../../../core/widgets/compact_button.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/diavicon_menu_item.dart';
import '../../../core/widgets/menu_drawer_app_bar.dart';

import '../models/estrutura_model.dart'; 
import '../widgets/elemento_estrutural_card.dart';
import '../widgets/estrutura_home_header.dart';
import '../widgets/progresso_projeto_card.dart';
import 'estrutura_informacao_screen.dart';

class EstruturaHomeScreen extends StatelessWidget {
  final EstruturaModel estrutura; 
  final String projetoId;

  const EstruturaHomeScreen({super.key, required this.estrutura, required this.projetoId});

  void _openElemento(
    BuildContext context, {
    required String elementoId,
    required String titulo,
    required String tipo,
    required String local,
    required String imageUrl,
  }) {
    context.push(
      '/estruturas/${estrutura.id}/elementos/$elementoId',
      extra: <String, dynamic>{
        'projetoId': projetoId,
        'estruturaId': estrutura.id,
        'elementoId': elementoId,
        'titulo': titulo,
        'tipo': tipo,
        'local': local,
        'imageUrl': imageUrl,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, 
      endDrawer: MenuDrawerAppBar(
        title: 'Menu da\nEstrutura',
        items: [
          DiaviconMenuItem(
              icon: Icons.info_outline,
              label: 'Informações',
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(context, MaterialPageRoute(builder: (_) => EstruturaInformacaoScreen(estrutura: estrutura, projetoId: projetoId)));
              },
            ),
          DiaviconMenuItem(icon: Icons.layers_outlined, label: 'Planejamento', onTap: () {}),
          DiaviconMenuItem(icon: Icons.science_outlined, label: 'Ensaios', onTap: () {}),
          DiaviconMenuItem(icon: Icons.description_outlined, label: 'Relatórios', onTap: () {}),
          DiaviconMenuItem(icon: Icons.pie_chart_outline, label: 'Dashboard', onTap: () {}),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Estrutura', 
        showBackButton: true, 
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            const SizedBox(height: 2),
            const Text('Estrutura', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // O NOVO WIDGET DE CABEÇALHO AQUI
            EstruturaHomeHeader(
              imageUrl: estrutura.imageUrl,
              status: estrutura.status ?? 'Em Andamento',
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(estrutura.nome ?? 'Sem nome', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text('${estrutura.tipologiaNome ?? 'Sem tipologia'} - ${estrutura.tipoNome ?? 'Sem tipo'}\n${estrutura.idadeCalculada} Anos  CAA ${estrutura.caa ?? '-'}', style: const TextStyle(fontSize: 14, color: AppColors.hintText, height: 1.4)),
                  const SizedBox(height: 24),

                  // O NOVO WIDGET DE PROGRESSO AQUI
                  const ProgressoProjetoCard(progresso: 0.90), 
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Elementos Estruturais', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      CompactButton(text: 'Incluir', onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Expanded(flex: 5, child: CompactSearchBar(hintText: 'Local')),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: GestureDetector(
                          onTap: () {},
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Todos', style: TextStyle(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
                              SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down, color: AppColors.textDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElementoEstruturalCard(
                    titulo: 'V201',
                    tipo: 'Viga - Concreto armado',
                    local: 'Casa de máquinas',
                    imageUrl: 'assets/images/empresa.png',
                    onTap: () => _openElemento(
                      context,
                      elementoId: 'v201',
                      titulo: 'V201',
                      tipo: 'Viga - Concreto armado',
                      local: 'Casa de máquinas',
                      imageUrl: 'assets/images/empresa.png',
                    ),
                  ),
                  ElementoEstruturalCard(
                    titulo: 'P102',
                    tipo: 'Pilar - Concreto armado',
                    local: '1º Subsolo',
                    imageUrl: 'assets/images/empresa.png',
                    onTap: () => _openElemento(
                      context,
                      elementoId: 'p102',
                      titulo: 'P102',
                      tipo: 'Pilar - Concreto armado',
                      local: '1º Subsolo',
                      imageUrl: 'assets/images/empresa.png',
                    ),
                  ),
                  ElementoEstruturalCard(
                    titulo: 'P105',
                    tipo: 'Pilar - Concreto armado',
                    local: '3º Andar',
                    imageUrl: 'assets/images/empresa.png',
                    onTap: () => _openElemento(
                      context,
                      elementoId: 'p105',
                      titulo: 'P105',
                      tipo: 'Pilar - Concreto armado',
                      local: '3º Andar',
                      imageUrl: 'assets/images/empresa.png',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
