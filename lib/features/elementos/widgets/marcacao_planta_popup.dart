import 'package:diavicon/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Asset da planta mockada usada enquanto não há upload de planta real.
const String kPlantaMockAsset = 'assets/images/planta_elementos_info.png';

/// Marcação de um elemento sobre a planta.
///
/// As coordenadas [x] e [y] são **relativas** (0..1) ao tamanho da imagem da
/// planta, de forma a serem independentes de resolução/tela. [numero] é o
/// rótulo exibido dentro da bolinha (ordem/identificador do elemento na planta).
///
/// Mapeamento de backend (preparado, ainda NÃO persistido):
/// - [x] → coluna `elementos_estruturais.posicao_x`
/// - [y] → coluna `elementos_estruturais.posicao_y`
///
/// Quando o backend for liberado, basta mapear estes campos no
/// `ElementoModel` (posicaoX/posicaoY) no momento da criação/edição.
class MarcacaoPlanta {
  const MarcacaoPlanta({
    required this.x,
    required this.y,
    this.numero = 1,
  });

  final double x; // 0..1
  final double y; // 0..1
  final int numero;

  MarcacaoPlanta copyWith({double? x, double? y, int? numero}) {
    return MarcacaoPlanta(
      x: x ?? this.x,
      y: y ?? this.y,
      numero: numero ?? this.numero,
    );
  }

  /// Pronto para integração: payload já no formato das colunas do banco.
  Map<String, dynamic> toPosicaoMap() => <String, dynamic>{
        'posicao_x': x,
        'posicao_y': y,
      };
}

/// Bolinha laranja numerada que representa a marcação na planta.
///
/// Segue o padrão do design (badge `#F9A232`, número branco, sombra azul).
class MarcacaoBolinha extends StatelessWidget {
  const MarcacaoBolinha({super.key, required this.numero, this.tamanho = 26});

  final int numero;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A57E8).withValues(alpha: 0.30),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$numero',
        style: GoogleFonts.lato(
          color: Colors.white,
          fontSize: tamanho * 0.46,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

/// Abre o popup de marcação em planta e devolve a [MarcacaoPlanta] escolhida,
/// ou `null` se o usuário fechar/cancelar.
Future<MarcacaoPlanta?> showMarcacaoPlantaPopup(
  BuildContext context, {
  String plantaAsset = kPlantaMockAsset,
  MarcacaoPlanta? inicial,
  int numero = 1,
}) {
  return showDialog<MarcacaoPlanta>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => MarcacaoPlantaPopup(
      plantaAsset: plantaAsset,
      marcacaoInicial: inicial,
      numero: numero,
    ),
  );
}

/// Popup que exibe a planta e permite tocar para posicionar a marcação.
class MarcacaoPlantaPopup extends StatefulWidget {
  const MarcacaoPlantaPopup({
    super.key,
    this.plantaAsset = kPlantaMockAsset,
    this.marcacaoInicial,
    this.numero = 1,
  });

  final String plantaAsset;
  final MarcacaoPlanta? marcacaoInicial;
  final int numero;

  @override
  State<MarcacaoPlantaPopup> createState() => _MarcacaoPlantaPopupState();
}

class _MarcacaoPlantaPopupState extends State<MarcacaoPlantaPopup> {
  /// Centro da marcação em coordenadas relativas (0..1). Nulo até o 1º toque.
  Offset? _ponto;

  int get _numero => widget.marcacaoInicial?.numero ?? widget.numero;

  @override
  void initState() {
    super.initState();
    final inicial = widget.marcacaoInicial;
    if (inicial != null) {
      _ponto = Offset(inicial.x, inicial.y);
    }
  }

  bool get _podeSalvar => _ponto != null;

  void _salvar() {
    final ponto = _ponto;
    if (ponto == null) return;
    Navigator.of(context).pop(
      MarcacaoPlanta(x: ponto.dx, y: ponto.dy, numero: _numero),
    );
  }

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
                  'Selecione o local na planta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    color: const Color(0xFF3E3E3D),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                // ── Dica de uso ──────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _ponto == null
                        ? 'Toque na planta para posicionar a marcação.'
                        : 'Toque novamente para reposicionar.',
                    style: GoogleFonts.lato(
                      color: const Color(0xFF3D3D3D),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Planta clicável ──────────────────────────────────────────
                _PlantaInterativa(
                  plantaAsset: widget.plantaAsset,
                  numero: _numero,
                  ponto: _ponto,
                  onTap: (relativo) => setState(() => _ponto = relativo),
                ),
                const SizedBox(height: 18),
                // ── Botão salvar ─────────────────────────────────────────────
                Center(
                  child: _SalvarButton(
                    onPressed: _podeSalvar ? _salvar : null,
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

/// Área da planta: imagem mockada com a bolinha posicionada por toque.
class _PlantaInterativa extends StatelessWidget {
  const _PlantaInterativa({
    required this.plantaAsset,
    required this.numero,
    required this.ponto,
    required this.onTap,
  });

  final String plantaAsset;
  final int numero;
  final Offset? ponto;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD9D9D9),
      padding: const EdgeInsets.all(6),
      child: AspectRatio(
        aspectRatio: 317 / 367, // proporção da moldura no design
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final ponto = this.ponto;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final local = details.localPosition;
                  onTap(Offset(
                    (local.dx / w).clamp(0.0, 1.0),
                    (local.dy / h).clamp(0.0, 1.0),
                  ));
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(plantaAsset, fit: BoxFit.cover),
                    if (ponto != null)
                      Positioned(
                        left: (ponto.dx * w) - 13,
                        top: (ponto.dy * h) - 13,
                        child: MarcacaoBolinha(numero: numero),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SalvarButton extends StatelessWidget {
  const _SalvarButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.30),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          'Salvar',
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
