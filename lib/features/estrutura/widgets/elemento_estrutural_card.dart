import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ElementoEstruturalCard extends StatelessWidget {
  final String titulo;
  final String tipo;
  final String local;
  final String imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ElementoEstruturalCard({
    super.key,
    required this.titulo,
    required this.tipo,
    required this.local,
    required this.imageUrl,
    this.onTap,
    this.onLongPress,
  });

  Widget _buildAvatar() {
    Widget fallback() => Container(
          width: 60,
          height: 60,
          color: Colors.grey[200],
          child: const Icon(Icons.image_not_supported, color: Colors.grey),
        );

    // Fotos de elementos reais vêm como URL do Storage; mocks usam asset.
    if (imageUrl.startsWith('http')) {
      return ImagemStorage.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
      );
    }

    return Image.asset(
      imageUrl,
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipOval(child: _buildAvatar()),
                const SizedBox(width: 16),
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.hintText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        local,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
