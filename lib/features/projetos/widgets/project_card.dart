import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final double progress;
  final BadgeStatus status; // Agora usando o seu Enum
  final String priority;
  final String imageUrl;

  const ProjectCard({
    super.key,
    required this.title,
    required this.progress,
    required this.status,
    required this.priority,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32), // Bordas bem arredondadas como no design
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ÁREA DA FOTO COM BADGES OVERLAY
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Imagem da Obra
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: Image.asset(
                  imageUrl, // Se for do assets, ou use Image.network se vier do Supabase
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
              ),
              
              // O SEU STATUS BADGE (Esquerda)
              Positioned(
                top: 16,
                left: 16,
                child: StatusBadge(status: status),
              ),

              // BADGE DE PRIORIDADE (Direita - Branco com Ícone Laranja)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        priority,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // LOGO DIAVICON FLUTUANTE (O "selo" no canto inferior da imagem)
              Positioned(
                bottom: -12,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Image.asset('assets/images/logo_diavicon.png', height: 24),
                ),
              ),
            ],
          ),

          // 2. CONTEÚDO (Texto e Progresso)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.w900, 
                    color: AppColors.textDark
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progresso', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    Text('${(progress * 100).toInt()}%', 
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Barra de Progresso Arredondada
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade100,
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
                
                const SizedBox(height: 12),

                // Stack de Avatares da Equipe (Canto inferior direito)
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildTeamStack(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStack() {
    return SizedBox(
      width: 100,
      height: 32,
      child: Stack(
        children: [
          _positionedAvatar(0, 'assets/images/user.png'),
          _positionedAvatar(18, 'assets/images/user.png'),
          _positionedAvatar(36, 'assets/images/user.png'),
          Positioned(
            left: 54,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.orange,
              child: const Text('+2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionedAvatar(double left, String asset) {
    return Positioned(
      left: left,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CircleAvatar(radius: 12, backgroundImage: AssetImage(asset)),
      ),
    );
  }
}