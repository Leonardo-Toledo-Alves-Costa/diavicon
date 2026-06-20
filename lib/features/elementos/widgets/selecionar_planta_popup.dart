import 'package:diavicon/features/elementos/widgets/novo_arquivo_popup.dart';
import 'package:diavicon/features/elementos/widgets/planta_formato_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Uma planta/formato da estrutura exibida na seleção.
///
/// Mockado enquanto o upload de plantas reais não está disponível (outro dev
/// cuida dessa parte). Quando o backend for liberado, esta lista deve vir do
/// repositório de plantas da estrutura.
class PlantaFormato {
  const PlantaFormato({
    required this.titulo,
    required this.local,
    required this.detalhe,
    this.plantaAsset,
  });

  final String titulo;
  final String local;
  final String detalhe;

  /// Asset da planta a ser usada no popup de marcação. Nulo usa o mock padrão.
  final String? plantaAsset;
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

/// Abre o popup "Plantas e Formatos da Estrutura" e devolve a [PlantaFormato]
/// escolhida, ou `null` se o usuário fechar sem selecionar.
Future<PlantaFormato?> showSelecionarPlantaPopup(BuildContext context) {
  return showDialog<PlantaFormato>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const SelecionarPlantaPopup(),
  );
}

/// Popup que lista as plantas/formatos da estrutura para o usuário escolher
/// sobre qual planta fará a marcação.
class SelecionarPlantaPopup extends StatelessWidget {
  const SelecionarPlantaPopup({super.key, this.plantas = _plantasMock});

  final List<PlantaFormato> plantas;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final largura = (mediaQuery.size.width - 32).clamp(280.0, 350.0).toDouble();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: largura,
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Cabeçalho: botão fechar ──────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: _CloseButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                // ── Título ───────────────────────────────────────────────────
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
                // ── Busca (mock) + botão Novo (mock) ─────────────────────────
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
                // ── Lista de plantas ─────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final planta in plantas)
                          PlantaFormatoCard(
                            titulo: planta.titulo,
                            local: planta.local,
                            detalhe: planta.detalhe,
                            onTap: () =>
                                Navigator.of(context).pop<PlantaFormato>(planta),
                          ),
                      ],
                    ),
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
        border: Border.all(color: const Color(0xFFD9D9D9).withValues(alpha: 0.62)),
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

/// Botão "Novo" (mock — o cadastro de novas plantas é responsabilidade de
/// outra parte do app).
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
          backgroundColor: const Color(0xFFF9A232),
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

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(
          Icons.close,
          color: const Color(0xFF626365).withValues(alpha: 0.40),
          size: 24,
        ),
      ),
    );
  }
}
