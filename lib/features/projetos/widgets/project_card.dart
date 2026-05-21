import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final double progress;
  final BadgeStatus status;
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
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PARTE SUPERIOR: Imagem + Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: _buildCapaProjeto(),
              ),
              // Badge de Status (Esquerda)
              Positioned(
                top: 12,
                left: 12,
                child: _buildStatusLabel(),
              ),
              // Badge de Prioridade (Direita)
              Positioned(
                top: 12,
                right: 12,
                child: _buildPriorityLabel(),
              ),
              // Logo da Empresa Gestora / Cliente (Sobreposta)
              Positioned(
                bottom: -15,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Image.asset('assets/images/empresa.png', height: 40),
                ),
              ),
            ],
          ),

          // PARTE INFERIOR: Texto + Progresso
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                const Text('Progresso', style: TextStyle(fontSize: 12, color: AppColors.hintText)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFFEEEEEE),
                          color: _getProgressColor(),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Aqui entraria a Row de Avatares da Equipe
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers Visuais ---

  /// Renderiza a imagem baseado se é um link do banco, um asset padrão ou um arquivo local
  Widget _buildCapaProjeto() {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
      );
    } 
    // 2. Se for um arquivo local recém-tirado pela câmera/galeria
    else if (imageUrl.startsWith('/data') || imageUrl.startsWith('file://')) {
      return Image.file(
        File(imageUrl),
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } 
    else {
      return _fallbackImage();
    }
  }

  Widget _fallbackImage() {
    return Image.asset(
      'assets/images/project_placeholder1.png', // Ou um 'assets/images/projeto_placeholder.png'
      height: 140,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Color _getProgressColor() {
    if (status == BadgeStatus.concluido) return Colors.green;
    if (status == BadgeStatus.cancelado) return Colors.red;
    return AppColors.primary;
  }

  Widget _buildStatusLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status == BadgeStatus.concluido ? 'Concluído' : 'Em andamento',
        style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(priority, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}