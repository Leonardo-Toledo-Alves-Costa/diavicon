import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O conteúdo da tela (Projetos, Estruturas, etc)
      body: child,

      // 1. O BOTÃO DE + (Floating Action Button)
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        onPressed: () {
          // TODO: Abrir modal de criação
        },
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),

      // 2. POSICIONAMENTO "MORDENDO" O RODAPÉ
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // 3. O RODAPÉ CUSTOMIZADO
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Faz o recorte redondo
        notchMargin: 8.0, // Espaço entre o botão e o recorte
        color: Colors.white,
        elevation: 15,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // GRUPO DA ESQUERDA
              Row(
                children: [
                  _buildNavButton(
                    context,
                    icon: Icons.folder_outlined,
                    label: 'Projetos',
                    index: 0,
                    route: '/projetos',
                  ),
                  _buildNavButton(
                    context,
                    icon: Icons.layers_outlined,
                    label: 'Estruturas',
                    index: 1,
                    route: '/estruturas',
                  ),
                ],
              ),

              // ESPAÇO PARA O BOTÃO CENTRAL NÃO ATROPELAR
              const SizedBox(width: 48),

              // GRUPO DA DIREITA
              Row(
                children: [
                  _buildNavButton(
                    context,
                    icon: Icons.business_outlined,
                    label: 'Empresa',
                    index: 3,
                    route: '/empresa',
                  ),
                  _buildNavButton(
                    context,
                    icon: Icons.school_outlined,
                    label: 'Educação',
                    index: 4,
                    route: '/educacao',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Lógica de Seleção (Mantida a sua ideia original com GoRouter)
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/projetos')) return 0;
    if (location.startsWith('/estruturas')) return 1;
    if (location.startsWith('/empresa')) return 3;
    if (location.startsWith('/educacao')) return 4;
    return 0;
  }

  // Widget de botão individual para o menu
  Widget _buildNavButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int index,
    required String route,
  }) {
    final int selectedIndex = _calculateSelectedIndex(context);
    final bool isActive = selectedIndex == index;

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // Largura fixa para manter a simetria (aprox 20% da tela)
        width: MediaQuery.of(context).size.width * 0.18,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : Colors.grey.shade400,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primary : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}