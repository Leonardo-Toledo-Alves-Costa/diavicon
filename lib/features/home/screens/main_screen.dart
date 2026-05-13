import 'package:diavicon/core/utils/diavicon_modal.dart';
import 'package:diavicon/core/widgets/rodape_seguro.dart';
import 'package:diavicon/features/projetos/widgets/new_project_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
class MainScreen extends StatelessWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final String location = GoRouterState.of(context).uri.toString();

    // CONTROLE DE TAMANHOS
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
                painter: BottomBarPainter(
                  humpWidth: humpWidth, 
                  humpHeight: humpHeight,
                ),
                child: Container(
                  height: barHeight + humpHeight,
                  padding: const EdgeInsets.only(top: humpHeight),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavItem(context, Icons.folder_open, 'Projetos', '/projetos', location),
                      const SizedBox(width: spaceBetweenPairs),
                      _buildNavItem(context, Icons.layers_outlined, 'Estruturas', '/estruturas', location),
                      
                      const SizedBox(width: spaceBetweenCenter), 
                      
                      _buildNavItem(context, Icons.business_outlined, 'Empresa', '/minha-empresa', location),
                      const SizedBox(width: spaceBetweenPairs),
                      _buildNavItem(context, Icons.school_outlined, 'Educação', '/educacao', location),
                    ],
                  ),
                ),
              ),
            ),

            // O BOTÃO DE + 
            Positioned(
              left: (size.width / 2) - (fabSize / 2),
              bottom: fabBottomOffset,
              child: GestureDetector(
                onTap: () {
                  if (location.startsWith('/projetos')) {
                    showDiaviconModal(
                      context: context,
                      title: 'Novo Projeto',
                      body: const NewProjectBody(),
                    );
                  }
                },
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
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
                      child: const Icon(Icons.add, color: Colors.white, size: plusIconSize, fontWeight: FontWeight.w900,), 
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData icon, String label, String route, String location) {
    final bool isSelected = location.startsWith(route);
    return InkWell(
      onTap: () => context.go(route),
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
    );
  }
}

// O PINTOR DO CUCURUTO
class BottomBarPainter extends CustomPainter {
  final double humpWidth;
  final double humpHeight;

  BottomBarPainter({required this.humpWidth, required this.humpHeight});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Path path = Path();
    double center = size.width / 2;

    path.moveTo(0, humpHeight);
    path.lineTo(center - humpWidth / 2, humpHeight); 
    
    path.cubicTo(
      center - humpWidth / 3, humpHeight, 
      center - humpWidth / 2.5, 0,        
      center, 0,                          
    );
    path.cubicTo(
      center + humpWidth / 2.5, 0,        
      center + humpWidth / 3, humpHeight, 
      center + humpWidth / 2, humpHeight,
    );
    
    path.lineTo(size.width, humpHeight);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.12), 12, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BottomBarPainter oldDelegate) {
    return oldDelegate.humpWidth != humpWidth || oldDelegate.humpHeight != humpHeight;
  }
}