import 'package:flutter/material.dart';

class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onMenuPressed; // O parâmetro que faltava

  const MenuAppBar({
    super.key,
    required this.title,
    this.onMenuPressed, // Recebe a função da tela pai
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // Essencial para o extendBodyBehindAppBar
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // O botão que vai abrir o seu MenuDrawerAppBar
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: onMenuPressed, // Quando clicado, executa o comando do Scaffold
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}