import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ElementoEstruturalCard extends StatelessWidget {
  final String titulo;
  final String tipo;
  final String local;
  final String imageUrl;

  const ElementoEstruturalCard({
    super.key,
    required this.titulo,
    required this.tipo,
    required this.local,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Sombra bem suave
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagem Circular
          ClipOval(
            child: Image.asset(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Informações em Coluna
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipo,
                  style: const TextStyle(fontSize: 13, color: AppColors.hintText),
                ),
                const SizedBox(height: 2),
                Text(
                  local,
                  style: const TextStyle(fontSize: 13, color: AppColors.hintText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}