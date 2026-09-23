import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// O cachorrinho mascote com um balão de fala — acompanha o cadastro (antes
/// ficava nas telas de questionário, que foram removidas do fluxo).
class CachorroGuia extends StatelessWidget {
  final String fala;
  final double altura;

  const CachorroGuia({super.key, required this.fala, this.altura = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            'assets/images/cachorro.png',
            height: altura,
            fit: BoxFit.contain,
            semanticLabel: 'Mascote da Diavicon',
          ),
          const SizedBox(width: 4),
          Align(
            alignment: const Alignment(0, -0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              // Branco: as telas do cadastro têm fundo cinza claro.
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(
                fala,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
