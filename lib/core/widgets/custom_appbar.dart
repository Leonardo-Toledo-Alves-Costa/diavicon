import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? extraActions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 4,
      centerTitle: true,
      // Design: Bordas arredondadas de 32px no fundo
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      
      // Botão de Voltar (Seta branca)
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(), 
            )
          : null,
          
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Lato',
        ),
      ),
      
      actions: [
        // 1. Ações Extras (se você quiser colocar algo antes do sino)
        if (extraActions != null) ...extraActions!,

        // 2. Ícone de Notificações (Sininho)
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {
            // Lógica de notificações aqui
          },
        ),

        // 3. Ícone de Menu (Hambúrguer) com o Builder Salvador
        Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                // Agora ele encontra o endDrawer do Scaffold da tela atual!
                Scaffold.of(context).openEndDrawer();
              },
            );
          },
        ),
        
        const SizedBox(width: 8), // Pequeno respiro na borda direita
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}