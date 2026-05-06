// lib/core/widgets/menu_drawer_app_bar.dart

import 'package:flutter/material.dart';

class MenuDrawerAppBar extends StatelessWidget {
  final String title;
  // MUDANÇA AQUI: De List<DiaviconMenuItem> para List<Widget>
  final List<Widget> items; 

  const MenuDrawerAppBar({
    super.key, 
    required this.title, 
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 110,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(40)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // Agora o Dart aceita sem reclamar!
                children: items, 
              ),
            ),
          ],
        ),
      ),
    );
  }
}