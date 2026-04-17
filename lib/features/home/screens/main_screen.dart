import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(), // Garante que seja redondo
        elevation: 2,
        onPressed: () {
          // TODO: Abrir bottom sheet ou modal de "Novo Projeto / Nova Estrutura"
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.hintText,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          _buildNavItem(Icons.folder_outlined, 'Projetos', 0, context),
          _buildNavItem(Icons.layers_outlined, 'Estruturas', 1, context),
          const BottomNavigationBarItem(
            icon: Icon(
              Icons.add,
              color: Colors.transparent,
            ), // Ícone transparente
            label: '', // Sem texto
          ),
          _buildNavItem(Icons.business_outlined, 'Empresa', 3, context),
          _buildNavItem(Icons.school_outlined, 'Educação', 4, context),
        ],
      ),
    );
  }

  // Lógica para saber qual aba está ativa com base na rota do GoRouter
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/projetos')) return 0;
    if (location.startsWith('/estruturas')) return 1;
    if (location.startsWith('/empresa')) return 3;
    if (location.startsWith('/educacao')) return 4;
    return 0;
  }

  // Navegação disparada pelo clique no rodapé
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/projetos');
        break;
      case 1:
        context.go('/estruturas');
        break;
      case 3:
        context.go('/empresa');
        break;
      case 4:
        context.go('/educacao');
        break;
    }
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
    BuildContext context,
  ) {
    final int selectedIndex = _calculateSelectedIndex(context);
    final bool isActive = selectedIndex == index;

    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.white : AppColors.hintText),
      ),
      label: label,
    );
  }
}
