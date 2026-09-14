import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class EstruturaAdicionadaBody extends StatelessWidget {
  const EstruturaAdicionadaBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Força a coluna a ser o menor possível
      children: [
        // Ícone de Check Laranja (Ligeiramente menor para poupar altura)
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12), // Espaçamento reduzido de 20 para 12
        
        // Linha Divisória
        const Divider(
          color: AppColors.inputBorder,
          thickness: 1,
          indent: 24,
          endIndent: 24,
        ),
        const SizedBox(height: 12), // Espaçamento reduzido de 16 para 12
        
        // Texto de Sucesso
        const Text(
          'Estrutura adicionada\nao projeto',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
            height: 1.2, // Reduz o espaço em branco entre as duas linhas do texto
          ),
        ),
        // O SizedBox extra que ficava aqui embaixo foi removido!
      ],
    );
  }
}