import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/projetos_provider.dart';

class ProjetosHeader extends ConsumerWidget {
  final double topPadding;

  const ProjetosHeader({
    super.key,
    required this.topPadding,
  });

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
                  IconButton(
                    icon:  Image.asset('assets/images/user.png', width: 42, height: 42, fit: BoxFit.cover),
                    onPressed: () {
                      context.push('/perfis');
                    },
                  ),
                  const Text(
                    'Projetos',
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
                  // BOTÃO DE LOGOUT PROVISÓRIO
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: 'Sair (Teste)',
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      ref.invalidate(currentUserProvider);
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Acompanhe o progresso das suas iniciativas',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'Lato',
                ),
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
              hintText: 'Buscar projetos ou clientes...',
              onChanged: (val) {
                // Atualiza o estado da busca no Riverpod
                ref.read(searchQueryProvider.notifier).state = val;
              },
            ),
          ),
        ),
      ],
    );
  }
}