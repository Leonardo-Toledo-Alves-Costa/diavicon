import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/menu_app_bar.dart';
import '../../../core/widgets/compact_search_bar.dart';
import '../../../core/widgets/compact_button.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Faz a imagem começar no topo absoluto
      extendBodyBehindAppBar: true, 
      appBar: const MenuAppBar(title: 'Projeto'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGEM COM SOBREPOSIÇÃO
            Stack(
              children: [
                Image.asset(
                  'assets/images/obra.png',
                  height: 220, // Altura maior para compensar a sobreposição
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                // Badge de Prioridade
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info, color: AppColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text('Média', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Projeto ABC',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  // Bloco da Empresa
                  Row(
                    children: [
                      Image.asset('assets/images/empresa.png', height: 35),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Empresa Engenharia', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Gestora', style: TextStyle(color: AppColors.hintText, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Card de Progresso Bege
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [Text('Progresso'), Text('0%')],
                        ),
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(value: 0.02, color: AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Seção Estruturas com widgets compactos
                  Row(
                    children: [
                      const Text('Estruturas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      const Expanded(child: CompactSearchBar(hintText: 'Nome da estrutura')),
                      const SizedBox(width: 8),
                      CompactButton(text: 'Incluir', onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: 48),
                  // Empty State
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 60, color: AppColors.hintText),
                        SizedBox(height: 16),
                        Text('Projeto sem estruturas incluídas', style: TextStyle(color: AppColors.hintText)),
                      ],
                    ),
                  ),
                  // Respiro final para o rodapé flutuante
                  const SizedBox(height: 120), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}