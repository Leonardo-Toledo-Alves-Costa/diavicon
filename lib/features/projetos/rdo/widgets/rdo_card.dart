import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/rdo_realizado_model.dart';
import 'equipe_avatares.dart';
import 'rdo_status_badge.dart';

/// Card de um RDO — único componente usado tanto em "RDOs registrados" (de
/// uma empresa, num projeto) quanto em "Meus RDOs" (todas as empresas do
/// usuário, todos os projetos), para as duas listas serem visualmente
/// idênticas. [subtituloProjeto] é a única diferença visual entre os dois
/// contextos: só aparece quando o card não está dentro do contexto de um
/// único projeto já conhecido pela tela.
class RdoCard extends StatelessWidget {
  final RdoRealizadoModel rdo;
  final String projetoId;
  final String? subtituloProjeto;
  final VoidCallback onTap;

  const RdoCard({
    super.key,
    required this.rdo,
    required this.projetoId,
    required this.onTap,
    this.subtituloProjeto,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtituloProjeto != null) ...[
              Text(
                subtituloProjeto!,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rdo.data,
                  style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D)),
                ),
                RdoStatusBadge(status: rdo.status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Equipe:', style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium)),
            const SizedBox(height: 6),
            EquipeAvataresCompacto(projetoId: projetoId, nomes: rdo.equipe),
            const SizedBox(height: 10),
            _buildLinhaTurno(Icons.wb_sunny_outlined, 'Manhã', rdo.manha),
            const SizedBox(height: 4),
            _buildLinhaTurno(Icons.engineering_outlined, 'Tarde', rdo.tarde),
            const SizedBox(height: 4),
            _buildLinhaTurno(Icons.nightlight_round, 'Noite', rdo.noite),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaTurno(IconData icone, String titulo, TurnoRealizado turno) {
    if (!turno.preenchido) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(icone, size: 16, color: AppColors.greyMedium),
        const SizedBox(width: 6),
        Text(
          '$titulo: ${turno.chegada} - ${turno.inicio}',
          style: GoogleFonts.lato(fontSize: 12, color: AppColors.greyMedium),
        ),
      ],
    );
  }
}
