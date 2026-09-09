import 'package:diavicon/features/empresa/screens/editar_tabelas_screen.dart';
import 'package:diavicon/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/empresa_model.dart';

class EmpresaHeader extends ConsumerWidget {
  final double topPadding;
  final EmpresaModel empresa;
  final VoidCallback onOpenDrawer;

  const EmpresaHeader({
    super.key,
    required this.topPadding,
    required this.empresa,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotoUrlAsync = ref.watch(fotoUsuarioProvider);

    // Medidas base para controlar perfeitamente o layout
    final double orangeHeight = 130 + topPadding;
    const double coverHeight = 140;
    const double overlap = 30;
    const double avatarRadius = 50;

    // Cálculos de posição
    final double coverTop = orangeHeight - overlap;
    final double coverBottom = coverTop + coverHeight;

    return SizedBox(
      height: coverBottom + avatarRadius + 10,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Capa
          Positioned(
            top: coverTop,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/header_empresas_home.png',
              height: coverHeight,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(height: coverHeight, color: Colors.grey[300]),
            ),
          ),

          // Fundo Laranja
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: orangeHeight,
            child: Container(
              padding: EdgeInsets.only(
                top: topPadding + 10,
                left: 24,
                right: 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: onOpenDrawer,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white24,
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: fotoUrlAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              error: (_, _) => Image.asset(
                                'assets/images/user.png',
                                fit: BoxFit.cover,
                              ),
                              data: (fotoUrl) {
                                if (fotoUrl != null && fotoUrl.isNotEmpty) {
                                  return Image.network(
                                    fotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/user.png',
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }
                                return Image.asset(
                                  'assets/images/user.png',
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const Text(
                        'Empresa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                          onPressed: () =>
                              context.pushNamed(AppRouteNames.notifications),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pesquise empresas na plataforma',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          //  Barra de Pesquisa por empresas
          Positioned(
            top: orangeHeight - 24,
            left: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              // child: CustomSearchBar(
              //   hintText: 'Buscar empresas ou serviços...',
              //   onChanged: (val) {},
              // ),
            ),
          ),

          // Logo Circular da Empresa
          Positioned(
            top: coverBottom - avatarRadius,
            left: 24,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Colors.white,
                backgroundImage: empresa.fotoUrl != null
                    ? NetworkImage(empresa.fotoUrl!)
                    : null,
                child: empresa.fotoUrl == null
                    ? const Icon(
                        Icons.domain,
                        size: 40,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ),
          ),

          // Botão de Editar Tabelas
          Positioned(
            top: coverBottom + 16,
            right: 24,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 2,
                shadowColor: Colors.black12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const EditarTabelasScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const Text(
                'Editar Tabelas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
