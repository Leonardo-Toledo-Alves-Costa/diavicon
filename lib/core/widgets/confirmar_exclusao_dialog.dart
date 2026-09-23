import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import 'compact_button.dart';

/// Exibe um modal padrão e elegante de confirmação de exclusão.
/// Retorna [true] se o usuário clicar em "Excluir" e [false] (ou null) se cancelar.
///
/// [extraContent], quando informado, entra logo abaixo da [mensagem] — usado
/// pelo sanfonado "O que mais será excluído junto" (ver
/// `resumo_exclusao_accordion.dart`) nas exclusões de projeto/estrutura/elemento.
Future<bool?> showConfirmarExclusaoDialog({
  required BuildContext context,
  String titulo = 'Confirmar Exclusão',
  required String mensagem,
  Widget? extraContent,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ocupa apenas o espaço necessário
            children: [
              //Ícone de destaque no topo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline, 
                  color: AppColors.error, 
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              // Título com mais peso
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF3E3E3D),
                ),
              ),
              const SizedBox(height: 12),
              
              // Mensagem com altura de linha (height) para respirar melhor
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF686868),
                  height: 1.4, 
                ),
              ),
              if (extraContent != null) ...[
                const SizedBox(height: 16),
                extraContent,
              ],
              const SizedBox(height: 32),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: CompactButton(
                      text: 'Cancelar',
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.greyMedium,
                      borderColor: const Color(0xFFD9D9D9),
                      elevation: 0,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CompactButton(
                      text: 'Excluir',
                      backgroundColor: AppColors.error, 
                      foregroundColor: Colors.white,
                      borderColor: AppColors.error,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}