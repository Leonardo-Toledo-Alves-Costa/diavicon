import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rdo_realizado_model.dart';

/// Selo de status do RDO — mesmo componente na lista, no detalhe e (futuro)
/// na tabela geral, pra as três cores/ícones nunca divergirem entre telas.
class RdoStatusBadge extends StatelessWidget {
  final RdoStatus status;
  final double fontSize;

  const RdoStatusBadge({super.key, required this.status, this.fontSize = 11});

  static const Color _corVisto = Color(0xFF3AA655);
  static const Color _corVistoFundo = Color(0xFFDFF5E3);
  static const Color _corRejeitadoFundo = Color(0xFFFBE2E1);

  @override
  Widget build(BuildContext context) {
    final (Color cor, Color fundo, IconData icone) = switch (status) {
      RdoStatus.postado => (
        AppColors.primary,
        const Color(0xFFFCE7CC),
        Icons.upload_rounded,
      ),
      RdoStatus.visto => (_corVisto, _corVistoFundo, Icons.check_rounded),
      RdoStatus.rejeitado => (
        AppColors.error,
        _corRejeitadoFundo,
        Icons.close_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: fontSize + 1, color: cor),
          const SizedBox(width: 4),
          Text(
            status.rotulo,
            style: GoogleFonts.lato(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}
