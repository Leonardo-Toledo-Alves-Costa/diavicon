import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Carrossel de boas-vindas mostrado quando a empresa acaba de ser criada:
/// plano Freemium, o que os planos pagos liberam, a comparação dos quatro
/// planos e como pedir a troca. Só a última imagem mostra "Entendi!".
///
/// As imagens ficam em assets/images/boas_vindas_planos_1..5.png (1080×1350).
Future<void> mostrarCarrosselBoasVindasPlanos(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => const _CarrosselBoasVindasPlanos(),
  );
}

class _CarrosselBoasVindasPlanos extends StatefulWidget {
  const _CarrosselBoasVindasPlanos();

  @override
  State<_CarrosselBoasVindasPlanos> createState() => _CarrosselBoasVindasPlanosState();
}

class _CarrosselBoasVindasPlanosState extends State<_CarrosselBoasVindasPlanos> {
  static const _imagens = [
    'assets/images/boas_vindas_planos_1.png',
    'assets/images/boas_vindas_planos_2.png',
    'assets/images/boas_vindas_planos_3.png',
    'assets/images/boas_vindas_planos_4.png',
    'assets/images/boas_vindas_planos_5.png',
  ];
  static const double _proporcao = 1080 / 1350;

  final _paginas = PageController();
  final _foco = FocusNode();
  int _atual = 0;

  bool get _ultima => _atual == _imagens.length - 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Carrega as próximas imagens antes de o usuário chegar nelas.
    for (final i in _imagens) {
      precacheImage(AssetImage(i), context);
    }
  }

  @override
  void dispose() {
    _paginas.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _irPara(int pagina) {
    if (pagina < 0 || pagina >= _imagens.length) return;
    _paginas.animateToPage(pagina, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  KeyEventResult _teclado(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _irPara(_atual + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _irPara(_atual - 1);
      return KeyEventResult.handled;
    }
    if (_ultima && (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.sizeOf(context);
    final largo = tela.width >= 700;
    // Altura reservada ao rodapé (botão/avanço) abaixo da imagem.
    const rodape = 72.0;
    final alturaMax = tela.height * 0.92 - rodape;
    final larguraMax = largo ? tela.width * 0.9 - 2 * 64 : tela.width - 32;
    var largura = larguraMax;
    var altura = largura / _proporcao;
    if (altura > alturaMax) {
      altura = alturaMax;
      largura = altura * _proporcao;
    }

    final imagem = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: largura,
        height: altura,
        child: PageView.builder(
          controller: _paginas,
          itemCount: _imagens.length,
          onPageChanged: (i) => setState(() => _atual = i),
          // Tocar/clicar na imagem avança (a 1ª imagem tem uma seta
          // desenhada que convida ao toque).
          itemBuilder: (_, i) => GestureDetector(
            onTap: i < _imagens.length - 1 ? () => _irPara(i + 1) : null,
            child: MouseRegion(
              cursor: i < _imagens.length - 1 ? SystemMouseCursors.click : SystemMouseCursors.basic,
              child: Image.asset(
                _imagens[i],
                fit: BoxFit.cover,
                semanticLabel: 'Boas-vindas à DIAVICON, página ${i + 1} de ${_imagens.length}',
              ),
            ),
          ),
        ),
      ),
    );

    Widget seta(IconData icone, String dica, VoidCallback? aoTocar) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Tooltip(
            message: dica,
            child: Material(
              color: aoTocar == null ? Colors.white24 : Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: aoTocar,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icone, color: aoTocar == null ? Colors.white54 : AppColors.textDark),
                ),
              ),
            ),
          ),
        );

    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _teclado,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (largo) seta(Icons.chevron_left, 'Anterior', _atual > 0 ? () => _irPara(_atual - 1) : null),
                imagem,
                if (largo) seta(Icons.chevron_right, 'Próxima', _ultima ? null : () => _irPara(_atual + 1)),
              ],
            ),
            SizedBox(
              height: rodape,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _ultima
                      ? ElevatedButton(
                          key: const ValueKey('entendi'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(200, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          child: const Text('Entendi!'),
                        )
                      : TextButton.icon(
                          key: const ValueKey('proxima'),
                          onPressed: () => _irPara(_atual + 1),
                          style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(44, 44)),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(
                            largo ? 'Próxima  (${_atual + 1}/${_imagens.length})' : 'Deslize ou toque para avançar  (${_atual + 1}/${_imagens.length})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
