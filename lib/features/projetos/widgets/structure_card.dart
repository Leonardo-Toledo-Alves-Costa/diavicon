// lib/features/projetos/widgets/structure_card.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:diavicon/features/estrutura/screens/estrutura_home.dart';
import 'package:diavicon/features/estrutura/models/estrutura_model.dart';

class StructureCard extends StatelessWidget {
  final EstruturaModel estrutura;

  const StructureCard({super.key, required this.estrutura});

  // Função inteligente para gerir imagens da web ou assets locais
  Widget _buildImage() {
    const String defaultAsset = 'assets/images/obra.png'; // Imagem padrão caso não tenha foto

    if (estrutura.imageUrl == null || estrutura.imageUrl!.isEmpty) {
      return Image.asset(
        defaultAsset,
        height: 90,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      estrutura.imageUrl!,
      height: 90,
      width: double.infinity,
      fit: BoxFit.cover,
      // Se o link der erro de carregamento, ele volta para a imagem padrão suavemente
      errorBuilder: (context, error, stackTrace) => Image.asset(
        defaultAsset,
        height: 90,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navegação simples para a Home de Estrutura
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  EstruturaHomeScreen(estrutura: estrutura)),
        );
      },
      child: Container(
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
            // 1. Imagem Dinâmica com Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: _buildImage(),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      estrutura.status ?? 'Em Andamento', 
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
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
                  // Título da Estrutura
                  Text(
                    estrutura.nome ?? 'Sem nome',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Tipo de Estrutura
                  Text(
                    estrutura.tipo ?? 'Sem tipo',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Idade e CAA
                  Text(
                    '${estrutura.idadeAnos ?? '-'} Anos  CAA ${estrutura.caa ?? '-'}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    estrutura.conjuntoEstrutural ?? 'Sem setor vinculado',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.hintText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      value: 0.8, // Futuramente conectaremos isso a uma variável de progresso da API
                      minHeight: 5,
                      backgroundColor: Color(0xFFEEEEEE),
                      color: AppColors.primary, 
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