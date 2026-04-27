import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 1. OBTÉM A ROTA ATUAL PARA PINTAR OS ÍCONES
    final String location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      // 2. APPBAR REMOVIDA
      // Agora cada tela (Projetos, Detalhes, etc.) cuida do seu próprio topo.
      resizeToAvoidBottomInset: false,
      appBar: null,

      body: child, // Onde as telas de conteúdo são renderizadas

      // 3. BOTÃO CENTRAL (FAB)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () {
          // Ação para criar algo novo
        },
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),

      // 4. RODAPÉ (BOTTOM BAR)
      bottomNavigationBar: BottomAppBar(
        color: Colors.white, // REQUISITO: Fundo Branco
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.folder_open, 'Projetos', '/projetos', location),
            _buildNavItem(context, Icons.layers_outlined, 'Estruturas', '/estruturas', location),
            
            // Espaço vazio para o botão de "+" não atropelar os ícones
            const SizedBox(width: 40), 
            
            _buildNavItem(context, Icons.business, 'Empresa', '/empresa', location),
            _buildNavItem(context, Icons.school_outlined, 'Educação', '/educacao', location),
          ],
        ),
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA OS ITENS DO MENU ---

  Widget _buildNavItem(
    BuildContext context, 
    IconData icon, 
    String label, 
    String route, 
    String currentLocation
  ) {
    // Verifica se a rota deste ícone é a que está ativa no momento
    final bool isSelected = currentLocation.startsWith(route);
    
    return InkWell(
      onTap: () => context.go(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // REQUISITO: Laranja se selecionado, Cinza se não
          Icon(
            icon, 
            color: isSelected ? AppColors.primary : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              fontSize: 10, 
              color: isSelected ? AppColors.primary : Colors.grey[400],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}