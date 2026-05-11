import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class ModalSelecaoBase extends StatelessWidget {
  final Widget titulo;
  final List<Widget> filhos;
  final String? textoBotao;
  final IconData? iconeBotao; 
  final VoidCallback? aoPressionarBotao;

  const ModalSelecaoBase({
    super.key,
    required this.titulo,
    required this.filhos,
    this.textoBotao,
    this.iconeBotao, 
    this.aoPressionarBotao,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.greyLight, size: 28),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: titulo,
              ),
              const SizedBox(height: 24),
              
              ...filhos,
              
              if (textoBotao != null) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: aoPressionarBotao,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconeBotao != null) ...[
                            Icon(iconeBotao, color: AppColors.white, size: 22),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            textoBotao!,
                            style: AppTextStyles.corpoDestaqueBranco.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}