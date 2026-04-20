import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/diavicon_modal.dart';
import '../../projetos/widgets/new_project_body.dart';

class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Detecta se o teclado está aberto
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      // Impede que o Scaffold tente redimensionar o rodapé
      resizeToAvoidBottomInset: false, 
      
      body: child,

      // Oculta o botão se o teclado abrir
      floatingActionButton: isKeyboardOpen 
        ? null 
        : FloatingActionButton(
            backgroundColor: AppColors.primary, // #D99100
            shape: const CircleBorder(),
            elevation: 4,
            onPressed: () {
              showDiaviconModal(
                context: context,
                title: 'Novo projeto',
                body: const NewProjectBody(),
              );
            },
            child: const Icon(Icons.add, color: Colors.white, size: 30),
          ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Oculta a barra branca do rodapé se o teclado abrir
      bottomNavigationBar: isKeyboardOpen 
        ? const SizedBox.shrink() 
        : BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            color: Colors.white,
            elevation: 15,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Lado Esquerdo
                  Row(
                    children: [
                      _buildNavItem(context, Icons.folder_outlined, 'Projetos', '/projetos'),
                      _buildNavItem(context, Icons.layers_outlined, 'Estruturas', '/estruturas'),
                    ],
                  ),
                  const SizedBox(width: 48), // Espaço para o notch
                  // Lado Direito
                  Row(
                    children: [
                      _buildNavItem(context, Icons.business_outlined, 'Empresa', '/empresa'),
                      _buildNavItem(context, Icons.school_outlined, 'Educação', '/educacao'),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route) {
    // Lógica simples de cor baseada na rota (simplificada)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.hintText, size: 24),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.hintText)),
        ],
      ),
    );
  }
}