import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class HeaderImagemEditavel extends StatelessWidget {
  final String? imageUrl;
  final VoidCallback onEditPressed;

  const HeaderImagemEditavel({super.key, this.imageUrl, required this.onEditPressed});

  @override
  Widget build(BuildContext context) {
    const String defaultAsset = 'assets/images/sem_estrutura.png';

    return Stack(
      children: [
        (imageUrl == null || imageUrl!.isEmpty) 
          ? Image.asset(defaultAsset, width: double.infinity, height: 160, fit: BoxFit.cover)
          : Image.network(
              imageUrl!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.asset(defaultAsset, width: double.infinity, height: 160, fit: BoxFit.cover),
            ),
        Positioned(
          bottom: 16,
          right: 16,
          child: GestureDetector(
            onTap: onEditPressed,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white, 
                shape: BoxShape.circle, 
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]
              ),
              child: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 24),
            ),
          ),
        ),
      ],
    );
  }
}