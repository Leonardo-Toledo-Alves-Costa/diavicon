import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CardEstrutura extends StatelessWidget {
  final String title;
  final String type;
  final String details;
  final String group;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;
  final String? imageUrl; 

  const CardEstrutura({
    super.key,
    required this.title,
    required this.type,
    required this.details,
    required this.group,
    required this.isSelected,
    required this.onChanged,
    this.imageUrl, 
  });

 // Função interna para gerenciar a imagem e erros
  // AJUSTE: Diminuí o tamanho da imagem de 64 para 56 para ajudar a tornar o card mais fino.
  Widget _buildImage() {
    const String defaultAsset = 'assets/images/empresa.png';

    if (imageUrl == null || imageUrl!.isEmpty) {
      return Image.asset(
        defaultAsset,
        width: 56, // Antes era 64
        height: 56, // Antes era 64
        fit: BoxFit.cover,
      );
    }

    if (imageUrl!.startsWith('http')) {
      return Image.network(
        imageUrl!,
        width: 56, // Antes era 64
        height: 56, // Antes era 64
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          defaultAsset,
          width: 56, // Antes era 64
          height: 56, // Antes era 64
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      imageUrl!,
      width: 56, // Antes era 64
      height: 56, // Antes era 64
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        defaultAsset,
        width: 56, // Antes era 64
        height: 56, // Antes era 64
        fit: BoxFit.cover,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.26),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 7.0),
        child: Row(
          children: [
            // Imagem da estrutura 
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: _buildImage(), 
            ),
            const SizedBox(width: 12),
            
            // Informações em coluna
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900, 
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2), 
                  Text(
                    type,
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                  ),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    group,
                    style: const TextStyle(fontSize: 12, color: AppColors.hintText),
                  ),
                ],
              ),
            ),
            
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: AppColors.inputBorder),
            ),
          ],
        ),
      ),
    );
  }
}