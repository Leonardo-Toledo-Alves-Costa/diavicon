import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? extraActions;
  final Widget? titleWidget;
  final bool showMenuButton;

  final bool showNotificationButton;
  final int notificationCount;
  final VoidCallback? onNotificationPressed;

  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.extraActions,
    this.titleWidget,
    this.showMenuButton = true,
    this.showNotificationButton = true,
    this.notificationCount = 0,
    this.onNotificationPressed,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 4,
      centerTitle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),

      leading: showBackButton
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
            )
          : null,

      title:
          titleWidget ??
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

      actions: [
        if (showNotificationButton && onNotificationPressed != null)
          IconButton(
            icon: Badge(
              isLabelVisible: notificationCount > 0,
              backgroundColor: Colors.orange,
              label: Text(
                notificationCount > 99 ? '99+' : notificationCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Icons.notifications_none, color: Colors.white),
            ),
            onPressed: onNotificationPressed,
          ),

        // Ações Extras (injetadas por cada tela)
        ...?extraActions,

        // Ícone de Menu Padrão (abre o endDrawer)
        if (showMenuButton)
          Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              );
            },
          ),

        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);
}
