// lib/features/projetos/widgets/structure_card.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StructureCard extends StatelessWidget {
  const StructureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem com Badge [image_7b8e71.png]
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.asset(
                  'assets/images/obra.png', 
                  height: 90, 
                  width: double.infinity, 
                  fit: BoxFit.cover
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Em Andamento',
                    style: TextStyle(fontSize: 8, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estrutura 01', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Text('Edifício - Concreto Armado', style: TextStyle(fontSize: 10, color: AppColors.hintText)),
                const Text('25 Anos  CAA III', style: TextStyle(fontSize: 9, color: AppColors.hintText)),
                const SizedBox(height: 8),
                // Barra de progresso cinza [image_7b8e71.png]
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.8,
                    minHeight: 5,
                    backgroundColor: Color(0xFFEEEEEE),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}