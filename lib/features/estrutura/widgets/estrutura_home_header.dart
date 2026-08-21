import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EstruturaHomeHeader extends StatelessWidget {
  final String? imageUrl;
  final String status;

  const EstruturaHomeHeader({super.key, this.imageUrl, required this.status});

  @override
  Widget build(BuildContext context) {
    const String defaultAsset = 'assets/images/sem_estrutura.png';

    return Stack(
      children: [
        (imageUrl == null || imageUrl!.isEmpty)
            ? Image.asset(defaultAsset, width: double.infinity, height: 280, fit: BoxFit.cover)
            : Image.network(
                imageUrl!,
                width: double.infinity,
                height: 280,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(defaultAsset, width: double.infinity, height: 280, fit: BoxFit.cover),
              ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4],
                colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(16)),
            child: Text(
              status, 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}