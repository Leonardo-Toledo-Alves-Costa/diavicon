import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class InfoTooltipDialog extends StatelessWidget {
  final String titulo;
  final String texto;
  final String? imagemAsset;
  final Widget? tabelaOuWidgetCustom;

  const InfoTooltipDialog({
    super.key,
    required this.titulo,
    required this.texto,
    this.imagemAsset,
    this.tabelaOuWidgetCustom,
  });

  static void show(
    BuildContext context, {
    required String titulo,
    required String texto,
    String? imagemAsset,
    Widget? tabelaOuWidgetCustom,
  }) {
    showDialog(
      context: context,
      builder: (_) => InfoTooltipDialog(
        titulo: titulo,
        texto: texto,
        imagemAsset: imagemAsset,
        tabelaOuWidgetCustom: tabelaOuWidgetCustom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              texto,
              style: GoogleFonts.lato(fontSize: 16, color: const Color(0xFF555555), height: 1.4),
            ),
            if (imagemAsset != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(imagemAsset!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ],
            if (tabelaOuWidgetCustom != null) ...[
              const SizedBox(height: 12),
              tabelaOuWidgetCustom!,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Fechar', style: GoogleFonts.lato(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}