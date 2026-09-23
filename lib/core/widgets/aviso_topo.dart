import 'package:flutter/material.dart';

/// Aviso que aparece no alto da tela, por cima do conteúdo.
///
/// A mensagem padrão do Flutter (`SnackBar`) nasce colada no rodapé — longe de
/// onde a pessoa está olhando depois de apertar um botão no topo, e muitas
/// vezes escondida pelo teclado ou por um botão flutuante. Este aviso entra
/// pelo alto, some sozinho e pode ser fechado no toque.
///
/// Uso:
/// ```dart
/// mostrarAviso(context, 'Salvo com sucesso!', tipo: TipoAviso.sucesso);
/// ```
enum TipoAviso { sucesso, erro, neutro }

/// Cores e ícone de cada tipo. Verde com "check" para o que deu certo,
/// vermelho com "x" para o que falhou, branco para o resto.
({Color fundo, Color frente, IconData icone}) _estilo(TipoAviso tipo) {
  switch (tipo) {
    case TipoAviso.sucesso:
      return (fundo: const Color(0xFF1B7F4B), frente: Colors.white, icone: Icons.check_circle_rounded);
    case TipoAviso.erro:
      return (fundo: const Color(0xFFC62828), frente: Colors.white, icone: Icons.cancel_rounded);
    case TipoAviso.neutro:
      return (fundo: Colors.white, frente: const Color(0xFF2E3033), icone: Icons.info_outline_rounded);
  }
}

void mostrarAviso(
  BuildContext context,
  String mensagem, {
  TipoAviso tipo = TipoAviso.neutro,
  Duration duracao = const Duration(seconds: 4),
}) {
  // Camada raiz: o aviso fica por cima de janelas (diálogos) abertas, e não
  // escondido atrás delas.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _AvisoTopo(
      mensagem: mensagem,
      tipo: tipo,
      duracao: duracao,
      aoFechar: () {
        if (entrada.mounted) entrada.remove();
      },
    ),
  );
  overlay.insert(entrada);
}

class _AvisoTopo extends StatefulWidget {
  final String mensagem;
  final TipoAviso tipo;
  final Duration duracao;
  final VoidCallback aoFechar;

  const _AvisoTopo({
    required this.mensagem,
    required this.tipo,
    required this.duracao,
    required this.aoFechar,
  });

  @override
  State<_AvisoTopo> createState() => _AvisoTopoState();
}

class _AvisoTopoState extends State<_AvisoTopo> with SingleTickerProviderStateMixin {
  late final AnimationController _animacao = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    _animacao.forward();
    Future.delayed(widget.duracao, _sair);
  }

  Future<void> _sair() async {
    if (!mounted) return;
    // Sair um pouco mais rápido do que entrar: o aviso já foi lido.
    await _animacao.reverse(from: _animacao.value);
    widget.aoFechar();
  }

  @override
  void dispose() {
    _animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo(widget.tipo);
    final largura = MediaQuery.sizeOf(context).width;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false,
        child: Align(
          child: FadeTransition(
            opacity: _animacao,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _animacao, curve: Curves.easeOutCubic)),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: largura < 560 ? largura - 24 : 520),
                  child: GestureDetector(
                    onTap: _sair,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: estilo.fundo,
                        borderRadius: BorderRadius.circular(12),
                        border: widget.tipo == TipoAviso.neutro
                            ? Border.all(color: const Color(0xFFE2E0DC))
                            : null,
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(estilo.icone, color: estilo.frente, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.mensagem,
                              style: TextStyle(
                                color: estilo.frente,
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
