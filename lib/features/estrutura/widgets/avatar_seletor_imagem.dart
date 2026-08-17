import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AvatarSeletorImagem extends StatelessWidget {
  final File? imagemSelecionada;
  final VoidCallback onTap;

  const AvatarSeletorImagem({
    super.key,
    required this.imagemSelecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: AppColors.background,
              backgroundImage: imagemSelecionada != null
                  ? FileImage(imagemSelecionada!) as ImageProvider
                  : const AssetImage('assets/images/sem_estrutura.png'),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.textDark, width: 1.5),
                ),
                child: const Icon(Icons.edit_outlined, color: AppColors.textDark, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}