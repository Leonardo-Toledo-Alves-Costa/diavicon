import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DiaviconAlerts {
  static void show(BuildContext context, String titulo, String mensagem, {bool isErro = false, bool isAviso = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    bool isRemoved = false;

    void remover() {
      if (!isRemoved) {
        overlayEntry.remove();
        isRemoved = true;
      }
    }

    final Color corPrincipal = isErro ? Colors.red : (isAviso ? Colors.orange.shade800 : Colors.green);
    final IconData icone = isErro ? Icons.error_outline : (isAviso ? Icons.warning_amber_rounded : Icons.check_circle_outline);

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: -100, end: 0),
            builder: (context, double value, child) => Transform.translate(offset: Offset(0, value), child: child),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                border: Border(left: BorderSide(color: corPrincipal, width: 4)),
              ),
              child: Row(
                children: [
                  Icon(icone, color: corPrincipal, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 16)),
                        Text(mensagem, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: remover,
                    child: Text('Entendi', style: TextStyle(color: corPrincipal, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), remover);
  }
}