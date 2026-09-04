import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/diavicon_alerts.dart';
import 'package:diavicon/core/widgets/rodape_seguro.dart';
import 'package:diavicon/features/feed_educacao/screens/criar_post_screen.dart';
import 'package:diavicon/features/home/widgets/main_bottom_bar_painter.dart';
import 'package:diavicon/features/planos/planos_mensagens.dart';
import 'package:diavicon/features/planos/providers/armazenamento_provider.dart';
import 'package:diavicon/features/planos/providers/empresa_plano_atual_provider.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends ConsumerWidget {
  final Widget child;
  final VoidCallback onProjectQuickAction;

  const MainScreen({
    super.key,
    required this.child,
    required this.onProjectQuickAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final location = GoRouterState.of(context).uri.path;
    final planoAsync = ref.watch(empresaPlanoAtualProvider);

    const fabSize = 52.0;
    const innerCircleSize = 22.0;
    const plusIconSize = 14.0;
    const fabBottomOffset = 30.0;
    const barHeight = 65.0;
    const humpHeight = 27.0;
    const humpWidth = 83.0;
    const spaceBetweenCenter = 65.0;
    const spaceBetweenPairs = 30.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        bottomNavigationBar: const RodapeSeguro(),
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: barHeight),
                child: child,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CustomPaint(
                size: Size(size.width, barHeight + humpHeight),
                painter: const MainBottomBarPainter(
                  humpWidth: humpWidth,
                  humpHeight: humpHeight,
                ),
                child: Container(
                  height: barHeight + humpHeight,
                  padding: const EdgeInsets.only(top: humpHeight),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavItem(
                        context,
                        Icons.folder_open,
                        'Projetos',
                        AppRouteNames.projects,
                        AppPaths.projects,
                        location,
                      ),
                      const SizedBox(width: spaceBetweenPairs),
                      _buildNavItem(
                        context,
                        Icons.layers_outlined,
                        'Estruturas',
                        AppRouteNames.structures,
                        AppPaths.structures,
                        location,
                        onBlocked: planoAsync.value?.monitor == false
                            ? () => DiaviconAlerts.show(
                                context,
                                'Recurso do seu plano',
                                'Seu plano atual não inclui o monitoramento de estruturas. $kMensagemContatoVendas',
                                isAviso: true,
                              )
                            : null,
                      ),
                      const SizedBox(width: spaceBetweenCenter),
                      _buildNavItem(
                        context,
                        Icons.business_outlined,
                        'Empresas',
                        AppRouteNames.myCompany,
                        AppPaths.myCompany,
                        location,
                      ),
                      const SizedBox(width: spaceBetweenPairs),
                      _buildNavItem(
                        context,
                        Icons.school_outlined,
                        'Educação',
                        AppRouteNames.education,
                        AppPaths.education,
                        location,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: (size.width / 2) - (fabSize / 2),
              bottom: fabBottomOffset,
              child: Builder(
                builder: (context) {
                  final isFabDisabled =
                      location.startsWith(AppPaths.myCompany) ||
                      location.startsWith(AppPaths.structures);

                  return GestureDetector(
                    onTap: () async {
                      if (isFabDisabled) {
                        DiaviconAlerts.show(
                          context,
                          'Em desenvolvimento',
                          'As ações rápidas para esta tela estarão disponíveis em breve!',
                          isAviso: true,
                        );
                        return;
                      }

                      if (location.startsWith(AppPaths.projects)) {
                        onProjectQuickAction();
                        return;
                      }

                      if (location.startsWith(AppPaths.education)) {
                        if (planoAsync.value?.publicarFeedEdu == false) {
                          DiaviconAlerts.show(
                            context,
                            'Recurso do seu plano',
                            'Seu plano atual não permite publicar no feed educacional. $kMensagemContatoVendas',
                            isAviso: true,
                          );
                          return;
                        }

                        if (!await podeAdicionarArquivo(ref)) {
                          if (context.mounted) {
                            DiaviconAlerts.show(
                              context,
                              'Armazenamento esgotado',
                              'Sua empresa atingiu o limite de armazenamento do plano atual. $kMensagemContatoVendas',
                              isAviso: true,
                            );
                          }
                          return;
                        }

                        if (context.mounted) {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CriarPostScreen(),
                            ),
                          );
                        }
                      }
                    },
                    child: Opacity(
                      opacity: isFabDisabled ? 0.4 : 1,
                      child: Container(
                        width: fabSize,
                        height: fabSize,
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
                            width: innerCircleSize,
                            height: innerCircleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: plusIconSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String routeName,
    String routePath,
    String location, {
    bool isDisabled = false,
    VoidCallback? onBlocked,
  }) {
    final isSelected = location.startsWith(routePath) && !isDisabled;

    return InkWell(
      onTap: () {
        if (onBlocked != null) {
          onBlocked();
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
