import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class MenuAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? topTitle;
  final String? bottomTitle;
  final bool showBackButton;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationPressed;

  const MenuAppBar({
    super.key,
    required this.title,
    this.topTitle,
    this.bottomTitle,
    this.showBackButton = true,
    this.onMenuPressed,
    this.onNotificationPressed,
  });

  bool get _hasMultipleTitles => topTitle != null || bottomTitle != null;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      toolbarHeight: preferredSize.height,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      shadowColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x40000000),
              offset: Offset(0, 4),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: _HeaderTitle(
        topTitle: topTitle,
        title: title,
        bottomTitle: bottomTitle,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: onNotificationPressed ?? () {},
        ),
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: onMenuPressed ?? () {},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(_hasMultipleTitles ? 96 : 70);
}

class _HeaderTitle extends StatelessWidget {
  final String title;
  final String? topTitle;
  final String? bottomTitle;

  const _HeaderTitle({required this.title, this.topTitle, this.bottomTitle});

  @override
  Widget build(BuildContext context) {
    if (topTitle == null && bottomTitle == null) {
      return Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.lato(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (topTitle != null)
          Text(
            topTitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w300,
              height: 1.2,
            ),
          ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        if (bottomTitle != null)
          Text(
            bottomTitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
      ],
    );
  }
}
