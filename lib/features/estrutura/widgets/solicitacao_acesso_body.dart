import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SolicitacaoAcessoBody extends StatelessWidget {
  const SolicitacaoAcessoBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // campo titulo
        _buildLabelComAsterisco('Título da Solicitação', showInfo: true),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Solicitação 1',
            hintStyle: const TextStyle(color: AppColors.hintText),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 20),

        // Campo Mensagem
        _buildLabelComAsterisco('Mensagem', showInfo: false),
        const SizedBox(height: 8),
        TextFormField(
          maxLines: 4, 
          decoration: InputDecoration(
            hintText: 'Mensagem de Solicitação',
            hintStyle: const TextStyle(color: AppColors.hintText),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 32),

        // Botão Solicitar
        Center(
          child: SizedBox(
            width: 160,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Lógica para enviar a solicitação
                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Solicitar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para montar o asterisco vermelho
  Widget _buildLabelComAsterisco(String text, {required bool showInfo}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            text: text,
            style: const TextStyle(color: AppColors.hintText, fontSize: 14),
            children: const [
              TextSpan(text: '*', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        if (showInfo) ...[
          const SizedBox(width: 6),
          const Icon(Icons.info_outline, size: 16, color: AppColors.textDark),
        ]
      ],
    );
  }
}