import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TeamMemberItem extends StatelessWidget {
  final String name;
  final String role;
  final String imagePath;

  const TeamMemberItem({
    super.key,
    required this.name,
    required this.role,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    // Verifica se a imagem vem da internet ou é o placeholder local
    final bool isNetworkImage = imagePath.startsWith('http');

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.inputBorder,
            backgroundImage: isNetworkImage
                ? StorageNetworkImage(imagePath)
                : AssetImage(imagePath) as ImageProvider,
          ),
          const SizedBox(height: 6),
          Text(
            name.split(' ').first, // Pega só o primeiro nome como no protótipo
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          Text(
            role,
            style: const TextStyle(fontSize: 9, color: AppColors.hintText),
          ),
        ],
      ),
    );
  }
}