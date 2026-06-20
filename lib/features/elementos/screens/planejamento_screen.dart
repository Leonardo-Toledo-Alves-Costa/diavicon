import 'package:diavicon/core/constants/app_colors.dart';
import 'package:diavicon/core/widgets/custom_appbar.dart';
import 'package:diavicon/features/elementos/widgets/novo_arquivo_popup.dart';
import 'package:diavicon/features/elementos/widgets/planta_formato_card.dart';
import 'package:diavicon/features/elementos/widgets/selecionar_planta_popup.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tela "Planejamento" da estrutura: lista as plantas/formatos cadastrados.
///
/// Versão full-screen do mesmo conteúdo do popup de seleção de planta. Acessada
/// pelo item "Planejamento" no menu da Estrutura.
///
/// Cards mockados enquanto o upload real de plantas não está disponível (outro
/// dev cuida dessa parte) — quando o backend liberar, a lista vem do repositório.
class PlanejamentoScreen extends StatelessWidget {
  const PlanejamentoScreen({
    super.key,
    this.plantas = _plantasMock,
  });

  final List<PlantaFormato> plantas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: 'Estrutura',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: GoogleFonts.lato(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Estrutura',
              style: GoogleFonts.lato(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Planejamento',
              style: GoogleFonts.lato(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plantas e Formatos da Estrutura',
                style: GoogleFonts.lato(
                  color: const Color(0xFF3E3E3D),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: _BuscaMock()),
                  const SizedBox(width: 12),
                  _NovoButton(
                    onPressed: () => showNovoArquivoPopup(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final planta in plantas)
                      PlantaFormatoCard(
                        titulo: planta.titulo,
                        local: planta.local,
                        detalhe: planta.detalhe,
                        onTap: () {},
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plantas mockadas (espelham o design "Plantas e Formatos da Estrutura").
const List<PlantaFormato> _plantasMock = <PlantaFormato>[
  PlantaFormato(
    titulo: 'Planta Baixa do Subsolo',
    local: '2º Subsolo',
    detalhe: '15 Marcações de Ensaio',
  ),
  PlantaFormato(
    titulo: 'Proj Est Fundações',
    local: '3º Subsolo',
    detalhe: '05 Marcações de Ensaio',
  ),
  PlantaFormato(
    titulo: 'Proj Est Vigas',
    local: '2º Andar',
    detalhe: '02 Marcações de Ensaio',
  ),
];

/// Campo de busca apenas visual (a busca real virá com o upload de plantas).
class _BuscaMock extends StatelessWidget {
  const _BuscaMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border.all(color: const Color(0xFFD9D9D9).withValues(alpha: 0.62)),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Nome do arquivo ou local',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(
                color: const Color(0xFFCCCCCC),
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Icon(Icons.search, size: 17, color: Color(0xFFCCCCCC)),
        ],
      ),
    );
  }
}

/// Botão "Novo" laranja (abre o popup de novo arquivo).
class _NovoButton extends StatelessWidget {
  const _NovoButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          'Novo',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1,
          ),
        ),
      ),
    );
  }
}
