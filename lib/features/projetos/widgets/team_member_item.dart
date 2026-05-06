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
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.inputBorder,
            backgroundImage: AssetImage(imagePath), // Aqui usa o seu user.png
          ),
          const SizedBox(height: 6),
          Text(
            name.split(' ')[0], // Pega só o primeiro nome como no protótipo
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