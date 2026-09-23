import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rdo_realizado_model.dart';

/// Box único por turno reunindo chegada/início/saída + condições de trabalho
/// e clima — os 5 campos que a tela de detalhe do RDO precisa mostrar juntos
/// por turno, cada um vindo agora de sua própria coluna em `rdo_realizado`
/// (antes eram valores fixos repetidos nos 3 turnos).
class TurnoResumoCard extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final TurnoRealizado turno;

  const TurnoResumoCard({
    super.key,
    required this.titulo,
    required this.icone,
    required this.turno,
  });

  @override
  Widget build(BuildContext context) {
    if (!turno.preenchido) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icone, size: 18, color: AppColors.greyLight),
            const SizedBox(width: 10),
            Text(
              '$titulo — sem registro',
              style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMedium),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3E3E3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _campo('Chegada', turno.chegada)),
              Expanded(child: _campo('Início', turno.inicio)),
              Expanded(child: _campo('Saída', turno.saida.isEmpty ? '-' : turno.saida)),
            ],
          ),
          if (turno.condTrabalho.isNotEmpty || turno.condClima.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.greyVeryLight),
            const SizedBox(height: 10),
            Row(
              children: [
                if (turno.condTrabalho.isNotEmpty)
                  Expanded(child: _campo('Condição de trabalho', turno.condTrabalho)),
                if (turno.condClima.isNotEmpty)
                  Expanded(child: _campo('Condição climática', turno.condClima)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _campo(String rotulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: GoogleFonts.lato(fontSize: 10.5, color: AppColors.greyMedium),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: GoogleFonts.lato(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3E3E3D),
            ),
          ),
        ],
      ),
    );
  }
}
