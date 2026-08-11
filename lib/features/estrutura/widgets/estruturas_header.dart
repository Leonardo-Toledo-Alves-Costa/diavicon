import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../screens/estruturas_tab_screen.dart';

// 🔥 IMPORTANTE: Ajuste o caminho do auth_provider para onde ele está no seu projeto
import '../../auth/providers/auth_provider.dart'; 

class EstruturasHeader extends ConsumerWidget {
  final double topPadding;
  final VoidCallback? onOpenDrawer; // 🔥 1. A função chega por aqui

  const EstruturasHeader({
    super.key, 
    required this.topPadding,
    this.onOpenDrawer, 
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👇 Puxa a foto do usuário do banco de dados em tempo real
    final fotoUrlAsync = ref.watch(fotoUsuarioProvider);

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
                  // 👇 FOTO DO USUÁRIO
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: fotoUrlAsync.when(
                        loading: () => const SizedBox(
                          width: 42, 
                          height: 42, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                        error: (_, __) => Image.asset('assets/images/user.png', width: 42, height: 42, fit: BoxFit.cover),
                        data: (fotoUrl) {
                          if (fotoUrl != null && fotoUrl.isNotEmpty) {
                            return Image.network(
                              fotoUrl, 
                              width: 42, 
                              height: 42, 
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset('assets/images/user.png', width: 42, height: 42, fit: BoxFit.cover),
                            );
                          }
                          return Image.asset('assets/images/user.png', width: 42, height: 42, fit: BoxFit.cover);
                        },
                      ),
                    ),
                    // 🔥 2. A função é disparada aqui ao clicar!
                    onPressed: onOpenDrawer,
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
                    onPressed: () => context.push('/notificacoes'),
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