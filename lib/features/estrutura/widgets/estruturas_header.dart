import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../screens/estruturas_tab_screen.dart';

class EstruturasHeader extends ConsumerWidget {
  final double topPadding;

  const EstruturasHeader({super.key, required this.topPadding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 140 + topPadding,
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
                  const CircleAvatar(
                    radius: 20,
                    backgroundImage: AssetImage('assets/images/user_avatar.png'),
                  ),
                  const Text(
                    'Estruturas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => context.push('/notificacoes'), // Redireciona para as notificações padrão
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Gerencie e monitore suas estruturas',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Lato'),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -26,
          left: 24,
          right: 24,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CustomSearchBar(
              hintText: 'Buscar estruturas...',
              onChanged: (val) {
                ref.read(estruturaSearchQueryProvider.notifier).state = val;
              },
            ),
          ),
        ),
      ],
    );
  }
}