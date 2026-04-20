import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;

  const MenuAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary, // #D99100 oficial
      elevation: 0,
      centerTitle: true,
      // Curvatura profunda conforme prototipagem
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      leading: showBackButton 
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Lato',
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () {}),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70); // Altura aumentada para a curva
}