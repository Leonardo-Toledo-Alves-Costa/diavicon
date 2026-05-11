import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Títulos principais (GeoSlab703 Md BT conforme manual)
  static const TextStyle tituloPrincipal = TextStyle(
    fontFamily: 'GeoSlab703', 
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.greyDarkest,  
  );

  // Textos de botões e destaques dentro de cards (Lato )
  static const TextStyle corpoDestaqueBranco = TextStyle(
    fontFamily: 'Lato',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  // Texto padrão para o fundo do app (Lato )
  static const TextStyle corpoTextoEscuro = TextStyle(
    fontFamily: 'Lato',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // Subtextos e legendas dentro de cards (Lato )
  static const TextStyle corpoSubtextoBranco = TextStyle(
    fontFamily: 'Lato',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );

  // Labels de formulários (Lato )
  static const TextStyle labelCampo = TextStyle(
    fontFamily: 'Lato',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.greyMedium, 
  );
}