import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/liquido_penetrante_model.dart';

/// Pílula colorida de um status (Aprovado / Reprovado / Cabe análise).
class BadgeStatusLP extends StatelessWidget {
  final StatusLP? status;
  const BadgeStatusLP(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: s?.fundo ?? Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
      child: Text(
        s?.label ?? 'Sem status',
        style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w700, color: s?.cor ?? Colors.grey.shade700),
      ),
    );
  }
}

/// Contagem por status: três números + barra proporcional. É a análise do
/// ensaio (individual no elemento e geral na estrutura).
class ResumoContagemLP extends StatelessWidget {
  final ContagemStatusLP contagem;
  final String titulo;
  const ResumoContagemLP({super.key, required this.contagem, this.titulo = 'Resultado'});

  @override
  Widget build(BuildContext context) {
    final total = contagem.total;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF3E3E3D)))),
              Text('$total ${total == 1 ? 'ponto' : 'pontos'}', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in StatusLP.values) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: s.fundo, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Text('${contagem.de(s)}', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.w900, color: s.cor)),
                        Text(s.label, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: s.cor)),
                      ],
                    ),
                  ),
                ),
                if (s != StatusLP.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  for (final s in StatusLP.values)
                    if (contagem.de(s) > 0) Expanded(flex: contagem.de(s), child: Container(height: 8, color: s.cor)),
                  if (contagem.semStatus > 0) Expanded(flex: contagem.semStatus, child: Container(height: 8, color: Colors.grey.shade300)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
