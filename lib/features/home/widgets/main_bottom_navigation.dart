import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/features/home/widgets/main_bottom_bar_painter.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainBottomNavigation extends StatelessWidget {
  static const double barHeight = 65;

  static const double _humpHeight = 27;
  static const double _humpWidth = 83;
  static const double _fabSize = 52;
  static const double _fabBottomOffset = 30;
  static const double _innerCircleSize = 22;
  static const double _plusIconSize = 14;
  static const double _spaceBetweenCenter = 65;
  static const double _spaceBetweenPairs = 30;

  final String location;
  final VoidCallback onProjectQuickAction;

  const MainBottomNavigation({
    super.key,
    required this.location,
    required this.onProjectQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final isProjectRoute = location.startsWith(AppPaths.projects);

    return SizedBox(
      height: barHeight + _humpHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: const MainBottomBarPainter(
                humpWidth: _humpWidth,
                humpHeight: _humpHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: _humpHeight),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _NavigationItem(
                      icon: Icons.folder_open,
                      label: 'Projetos',
                      routeName: AppRouteNames.projects,
                      routePath: AppPaths.projects,
                      location: location,
                    ),
                    const SizedBox(width: _spaceBetweenPairs),
                    _NavigationItem(
                      icon: Icons.layers_outlined,
                      label: 'Estruturas',
                      routeName: AppRouteNames.structures,
                      routePath: AppPaths.structures,
                      location: location,
                      isDisabled: true,
                    ),
                    const SizedBox(width: _spaceBetweenCenter),
                    _NavigationItem(
                      icon: Icons.business_outlined,
                      label: 'Empresa',
                      routeName: AppRouteNames.myCompany,
                      routePath: AppPaths.myCompany,
                      location: location,
                    ),
                    const SizedBox(width: _spaceBetweenPairs),
                    _NavigationItem(
                      icon: Icons.school_outlined,
                      label: 'Educação',
                      routeName: AppRouteNames.education,
                      routePath: AppPaths.education,
                      location: location,
                      isDisabled: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: _fabBottomOffset,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (isProjectRoute) {
                    onProjectQuickAction();
                    return;
                  }

                  DiaviconAlerts.show(
                    context,
                    'Em desenvolvimento',
                    'As ações rápidas para esta tela estarão disponíveis em breve!',
                    isAviso: true,
                  );
                },
                child: Opacity(
                  opacity: isProjectRoute ? 1 : 0.4,
                  child: Container(
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: _innerCircleSize,
                        height: _innerCircleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: _plusIconSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String routeName;
  final String routePath;
  final String location;
  final bool isDisabled;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.routeName,
    required this.routePath,
    required this.location,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = location.startsWith(routePath) && !isDisabled;

    return InkWell(
      onTap: () {
        if (isDisabled) {
          DiaviconAlerts.show(
            context,
            'Em desenvolvimento',
            'Esta funcionalidade estará disponível em breve!',
            isAviso: true,
          );
          return;
        }

        context.goNamed(routeName);
      },
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
            else
              const SizedBox(height: 8),
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey[400],
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primary : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
