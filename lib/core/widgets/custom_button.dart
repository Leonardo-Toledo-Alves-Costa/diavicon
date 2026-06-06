import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool showArrow;
  final bool isLoading;
  
  final double? width;
  final double height;
  final double fontSize;
  final FontWeight? fontWeight;
  
  // 🔥 Agora ele aceita os seus estilos do AppTextStyles!
  final TextStyle? textStyle; 

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.showArrow = false,
    this.isLoading = false,
    this.width = double.infinity,
    this.height = 50,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w400,
    this.textStyle, // Adicionado aqui
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: width == double.infinity ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Text(
                    text,
                    // 🔥 Se você passar um textStyle, ele usa. Se não, usa o padrão do botão.
                    style: textStyle ?? TextStyle(
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                      letterSpacing: 0.5,
                      color: Colors.white, // Garante que a cor base seja branca se não passar estilo
                    ),
                  ),
                  if (showArrow) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}