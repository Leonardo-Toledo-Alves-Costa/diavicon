import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class PerfilHeader extends ConsumerWidget {
  final double topPadding;
  final String paginaAtual;

  const PerfilHeader({
    super.key,
    required this.topPadding,
    required this.paginaAtual,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 100 + topPadding,
          padding: EdgeInsets.only(top: topPadding + 10, left: 24, right: 24),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BackButton(
                    color: Colors.white,
                  ),
                  Text(
                    paginaAtual,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none,
                      color: Colors.white,
                    ),
                    onPressed: () => context.push('/notificacoes'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}