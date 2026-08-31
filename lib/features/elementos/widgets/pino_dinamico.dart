import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinoDinamico extends StatelessWidget {
  const PinoDinamico({super.key, required this.tipoMarcacao, this.nomeElemento, this.numero = 1});

  final String tipoMarcacao;
  final String? nomeElemento;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final tipo = tipoMarcacao.toLowerCase();
    final isCirculo = tipo == 'círculo';
    final isLinha = tipo == 'linha';
    final isPonto = tipo == 'ponto';

    // Configura as dimensões baseado no tipo
    double largura = 26;
    double altura = 26;
    if (isLinha) { largura = 50; altura = 12; } // Linha é mais larga e achatada
    if (isPonto) { largura = 16; altura = 16; } // Ponto é menorzinho

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: largura,
          height: altura,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            shape: (isCirculo || isPonto) ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: (!isCirculo && !isPonto) ? BorderRadius.circular(4) : null,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 2))],
          ),
          child: (nomeElemento == null && !isPonto && !isLinha) 
              ? Text('$numero', style: GoogleFonts.lato(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
              : null,
        ),
        
        if (nomeElemento != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
            child: Text(nomeElemento!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }
}