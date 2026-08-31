import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Espaço reservado pra publicidade, mostrado só quando o plano da empresa
/// tem `ads == true`. É um placeholder visual (mesma linguagem do badge
/// "Patrocinado" já usado no feed educacional) — não integra com nenhuma
/// rede de anúncios real; isso é uma decisão separada (qual SDK usar) que
/// ainda não foi tomada.
class AdsBannerPlaceholder extends StatelessWidget {
  const AdsBannerPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE87B1D), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_outlined, color: Color(0xFFE87B1D)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espaço publicitário', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF3E3E3D))),
                const SizedBox(height: 2),
                Text('Reservado para anúncios', style: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
