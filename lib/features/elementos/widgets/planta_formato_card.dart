import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Card de uma planta/formato da estrutura (ícone de arquivo + título, local e
/// quantidade de marcações). Usado na tela de Planejamento.
class PlantaFormatoCard extends StatelessWidget {
  const PlantaFormatoCard({
    super.key,
    required this.titulo,
    required this.local,
    required this.detalhe,
    this.onTap,
    this.iconAsset = 'assets/images/pdf.png',
  });

  final String titulo;
  final String local;
  final String detalhe;
  final VoidCallback? onTap;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    // Descobre se estamos lidando com uma imagem só pelo nome da string
    final esImagem = iconAsset.contains('image');

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 39,
                  height: 39,
                  // 🔥 Voltamos com o seu Image.asset para manter o seu PDF original!
                  child: Image.asset(
                    iconAsset,
                    fit: BoxFit.contain,
                    // 🔥 O segredo está aqui: se a imagem não existir na pasta, ele mostra o ícone de erro certo!
                    errorBuilder: (_, __, ___) => Icon(
                      esImagem ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                      color: const Color(0xFF3E3E3D),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF3E3E3D),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        local,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF3E3E3D),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalhe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lato(
                          color: const Color(0xFF686868),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}