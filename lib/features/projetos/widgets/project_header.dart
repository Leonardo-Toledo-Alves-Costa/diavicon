import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/projeto_model.dart';

class ProjectHeader extends StatelessWidget {
  final ProjetoModel projeto;
  const ProjectHeader({super.key, required this.projeto});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        projeto.imageUrl.startsWith('http')
            ? Image.network(
                projeto.imageUrl,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackImage(),
              )
            : Image.asset(
                projeto.imageUrl.isNotEmpty
                    ? projeto.imageUrl
                    : 'assets/images/project_placeholder1.png',
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackImage(),
              ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4],
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBadge(
                projeto.prioridadeNome,
                AppColors.primary,
                Icons.info,
              ),
              const SizedBox(height: 8),
              _buildStatusBadge(projeto.statusBadge),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/images/project_placeholder1.png',
      height: 280,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _buildBadge(String label, Color color, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: color, size: 14),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BadgeStatus status) {
    String label = 'Em Andamento';
    if (status == BadgeStatus.concluido) label = 'Concluído';
    if (status == BadgeStatus.cancelado) label = 'Cancelado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
