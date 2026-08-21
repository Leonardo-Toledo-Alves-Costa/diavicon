import 'package:diavicon/features/projetos/providers/notificacoes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; 
import '../constants/app_colors.dart';


class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? extraActions;
  final Widget? titleWidget;
  final bool showMenuButton;
  
  final bool showNotificationButton; 
  
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.extraActions,
    this.titleWidget,
    this.showMenuButton = true,
    this.showNotificationButton = true,
    this.onBackPressed, 
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 4,
      centerTitle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: onBackPressed ?? () => Navigator.of(context).pop(), 
            )
          : null,
          
      title: titleWidget ?? Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      actions: [

        if (showNotificationButton)
          Consumer(
            builder: (context, ref, child) {
              final asyncCount = ref.watch(contadorNaoLidasProvider);
              
              // Trata corretamente os estados do Stream para a interface não quebrar
              final qtdeNaoLidas = asyncCount.when(
                data: (valor) => valor,
                loading: () => 0,
                error: (err, stack) {
                  debugPrint('Erro no contador do badge: $err');
                  return 0;
                },
              );
              
              return IconButton(
                icon: Badge(
                  isLabelVisible: qtdeNaoLidas > 0, 
                  backgroundColor: Colors.orange,
                  label: Text(
                    qtdeNaoLidas > 99 ? '99+' : qtdeNaoLidas.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  child: const Icon(Icons.notifications_none, color: Colors.white),
                ),
                onPressed: () {
                  // Navegação
                },
              );
            },
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