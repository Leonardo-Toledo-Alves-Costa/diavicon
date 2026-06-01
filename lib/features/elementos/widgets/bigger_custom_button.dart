import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BiggerCustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height; // <-- NOVO PARÂMETRO ADICIONADO
  // Esse parâmetro permite adicionar uma altura personalizada ao botão, tornando-o mais flexível para diferentes contextos de uso.

  const BiggerCustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height, // <-- Recebendo a altura
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height, // <-- Aplicando a altura no Container
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF9A232),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF9A232).withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.8),
          elevation: 0,


          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),

        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
