import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/status_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ensaios/ensaios_geral/progresso/progresso_ensaios.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final double progress;
  final BadgeStatus status;
  final String priority;
  final String imageUrl;
  final List<String> teamAvatars;
  final String? empresaFotoUrl;
  // Com o id, o card calcula o progresso real (ensaios realizados ÷
  // contratados da empresa); sem ele usa [progress].
  final String? projetoId;

  const ProjectCard({
    super.key,
    required this.title,
    required this.progress,
    required this.status,
    required this.priority,
    required this.imageUrl,
    required this.teamAvatars,
    this.empresaFotoUrl,
    this.projetoId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: _buildCapaProjeto(),
              ),
              Positioned(top: 16, left: 16, child: StatusBadge(status: status)),
              Positioned(top: 16, right: 16, child: _buildPriorityLabel()),
              Positioned(
                bottom: -16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  // AQUI ENTRA A LOGO DA EMPRESA GESTORA
                  child: ClipOval(
                    child: empresaFotoUrl != null && empresaFotoUrl!.isNotEmpty
                        ? ImagemStorage.network(
                            empresaFotoUrl!,
                            height: 32,
                            width: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallbackLogo(),
                          )
                        : _fallbackLogo(),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Progresso e Equipe (Linha Superior) ────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Progresso',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    _buildTeamStack(),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Barra de Progresso e Porcentagem (Linha Inferior) ──────
                if (projetoId == null)
                  _linhaProgresso(progress)
                else
                  Consumer(
                    builder: (context, ref, _) => _linhaProgresso(
                      ref.watch(progressoProjetoProvider(projetoId!)).value?.fracao ?? 0,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper para o logo padrão da Diavicon se a empresa não tiver foto
  Widget _fallbackLogo() {
    return Image.asset(
      'assets/images/logo_diavicon.png',
      height: 32,
      width: 32,
      fit: BoxFit.contain, // contain para não cortar o escudo
    );
  }

  Widget _buildCapaProjeto() {
    const double imgHeight = 110;

    if (imageUrl.startsWith('http')) {
      return ImagemStorage.network(
        imageUrl,
        height: imgHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(imgHeight),
      );
    }

    if (imageUrl.startsWith('/data') || imageUrl.startsWith('file://')) {
      return Image.file(
        File(imageUrl.replaceFirst('file://', '')),
        height: imgHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(imgHeight),
      );
    }

    if (imageUrl.isNotEmpty) {
      return Image.asset(
        imageUrl,
        height: imgHeight,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(imgHeight),
      );
    }

    return _fallbackImage(imgHeight);
  }

  Widget _fallbackImage(double height) {
    return Image.asset(
      'assets/images/project_placeholder1.png',
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _buildPriorityLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info, color: Colors.orange, size: 14),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Text(
              priority,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaProgresso(double valor) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: valor,
              backgroundColor: Colors.grey.shade200,
              color: _getProgressColor(),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // O valor percentual na direita
        Text(
          '${(valor * 100).floor()}%',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Color _getProgressColor() {
    if (status == BadgeStatus.concluido) return Colors.green;
    if (status == BadgeStatus.cancelado) return Colors.red;
    return AppColors.primary;
  }

  Widget _buildTeamStack() {
    const double avatarRadius = 19;
    const double avatarOverlap = 12;

    final int visibleCount = teamAvatars.length.clamp(0, 3);
    final int extraCount = teamAvatars.length - visibleCount;

    List<Widget> avatars = [];
    for (int i = 0; i < visibleCount; i++) {
      avatars.add(
        _positionedAvatar(
          i * (2 * avatarRadius - avatarOverlap),
          teamAvatars[i],
          avatarRadius,
        ),
      );
    }

    if (extraCount > 0) {
      avatars.add(
        Positioned(
          left: visibleCount * (2 * avatarRadius - avatarOverlap),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.orange,
              child: Text(
                '+$extraCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: avatarRadius - 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final int totalItems = visibleCount + (extraCount > 0 ? 1 : 0);
    final double totalWidth = totalItems > 0
        ? (totalItems * (2 * avatarRadius)) - ((totalItems - 1) * avatarOverlap)
        : 0;

    return SizedBox(
      width: totalWidth,
      height: 2 * avatarRadius,
      child: Stack(
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.none,
        children: avatars,
      ),
    );
  }

  Widget _positionedAvatar(double left, String imageUrl, double radius) {
    final bool isNetwork = imageUrl.startsWith('http');

    return Positioned(
      left: left,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.greyVeryLight,
          backgroundImage: isNetwork
              ? StorageNetworkImage(imageUrl)
              : const AssetImage('assets/images/user.png') as ImageProvider,
        ),
      ),
    );
  }
}
