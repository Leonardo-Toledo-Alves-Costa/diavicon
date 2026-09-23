import 'package:diavicon/core/widgets/imagem_storage.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Fotos dos ensaios sem achatar.
///
/// O problema antigo: caixas de largura total com altura fixa (140, 200,
/// 350 px) e `BoxFit.cover`. Numa tela larga, a foto virava uma faixa fina e
/// cortada. Aqui a caixa segue uma PROPORÇÃO (a altura acompanha a largura) e
/// tem largura máxima. Tocar abre a foto inteira, sem corte, com zoom.

/// Foto em moldura com proporção fixa (padrão 4:3), cortando o mínimo.
class FotoEnsaio extends StatelessWidget {
  final ImageProvider? imagem;
  final double proporcao;
  final double? larguraMaxima;
  final double raio;

  /// Tocar abre a foto em tela cheia (padrão). Passe [aoTocar] para trocar
  /// isso, por exemplo para "trocar foto" num formulário.
  final VoidCallback? aoTocar;
  final bool ampliarAoTocar;

  /// Canto inferior direito (ex.: botão editar/excluir).
  final Widget? acao;

  /// Mostrado sem imagem (ex.: "Adicionar foto").
  final Widget? vazio;
  final String? legenda;

  const FotoEnsaio({
    super.key,
    required this.imagem,
    this.proporcao = 4 / 3,
    this.larguraMaxima = 560,
    this.raio = 14,
    this.aoTocar,
    this.ampliarAoTocar = true,
    this.acao,
    this.vazio,
    this.legenda,
  });

  @override
  Widget build(BuildContext context) {
    final img = imagem;
    Widget conteudo = AspectRatio(
      aspectRatio: proporcao,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(raio),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFEDEDED)),
            if (img != null)
              Image(
                image: img,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, sincrono) => AnimatedOpacity(
                  opacity: sincrono || frame != null ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                ),
                errorBuilder: (_, _, _) => const _FotoIndisponivel(),
              )
            else
              vazio ?? const _FotoIndisponivel(icone: Icons.add_a_photo_outlined, texto: 'Sem foto'),
            if (legenda != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                    ),
                  ),
                  child: Text(
                    legenda!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (acao != null) Positioned(right: 8, bottom: 8, child: acao!),
          ],
        ),
      ),
    );

    final toque = aoTocar ?? (img != null && ampliarAoTocar ? () => abrirFotoTelaCheia(context, [img]) : null);
    if (toque != null) {
      conteudo = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(raio),
        child: InkWell(
          borderRadius: BorderRadius.circular(raio),
          onTap: toque,
          child: conteudo,
        ),
      );
    }
    if (larguraMaxima != null) {
      conteudo = Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: larguraMaxima!), child: conteudo),
      );
    }
    return conteudo;
  }
}

/// Grade de miniaturas quadradas que se ajusta à largura. Tocar abre a
/// galeria em tela cheia a partir daquela foto.
class GradeFotosEnsaio extends StatelessWidget {
  final List<ImageProvider> imagens;
  final double tamanhoMinimo;
  final Widget? botaoAdicionar;
  final void Function(int indice)? aoRemover;
  final List<String?>? legendas;

  const GradeFotosEnsaio({
    super.key,
    required this.imagens,
    this.tamanhoMinimo = 96,
    this.botaoAdicionar,
    this.aoRemover,
    this.legendas,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const espaco = 8.0;
        final colunas = ((c.maxWidth + espaco) / (tamanhoMinimo + espaco)).floor().clamp(2, 8);
        final lado = (c.maxWidth - espaco * (colunas - 1)) / colunas;
        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (var i = 0; i < imagens.length; i++)
              SizedBox(
                width: lado,
                height: lado,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FotoEnsaio(
                      imagem: imagens[i],
                      proporcao: 1,
                      larguraMaxima: null,
                      raio: 10,
                      aoTocar: () => abrirFotoTelaCheia(context, imagens, inicial: i, legendas: legendas),
                    ),
                    if (aoRemover != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _BotaoRedondo(
                          icone: Icons.close_rounded,
                          dica: 'Remover foto',
                          aoTocar: () => aoRemover!(i),
                        ),
                      ),
                  ],
                ),
              ),
            if (botaoAdicionar != null) SizedBox(width: lado, height: lado, child: botaoAdicionar),
          ],
        );
      },
    );
  }
}

/// Botão "adicionar foto" no mesmo formato das miniaturas.
class BotaoAdicionarFoto extends StatelessWidget {
  final VoidCallback? aoTocar;
  final String texto;

  const BotaoAdicionarFoto({super.key, required this.aoTocar, this.texto = 'Adicionar'});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8EE),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: aoTocar,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFA85A00))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Imagem na proporção REAL do arquivo, sem corte, com camadas por cima no
/// mesmo quadro (marcadores de pontos, grids). Posições em % ficam presas à
/// foto, em qualquer largura de tela.
class ImagemProporcaoReal extends StatefulWidget {
  final ImageProvider imagem;
  final double? larguraMaxima;
  final double? alturaMaxima;
  final double raio;

  /// Camadas sobre a imagem, recebendo o tamanho exato da área da foto.
  final Widget Function(BuildContext context, Size tamanho)? sobreposicao;

  const ImagemProporcaoReal({
    super.key,
    required this.imagem,
    this.larguraMaxima,
    this.alturaMaxima = 560,
    this.raio = 14,
    this.sobreposicao,
  });

  @override
  State<ImagemProporcaoReal> createState() => _ImagemProporcaoRealState();
}

class _ImagemProporcaoRealState extends State<ImagemProporcaoReal> {
  double? _proporcao;
  ImageStream? _stream;
  ImageStreamListener? _ouvinte;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolver();
  }

  @override
  void didUpdateWidget(covariant ImagemProporcaoReal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagem != widget.imagem) _resolver();
  }

  void _resolver() {
    final stream = widget.imagem.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _pararDeOuvir();
    _stream = stream;
    _ouvinte = ImageStreamListener(
      (info, _) {
        final p = info.image.width / info.image.height;
        if (mounted && p.isFinite && p > 0 && p != _proporcao) setState(() => _proporcao = p);
      },
      onError: (_, _) {
        if (mounted) setState(() => _proporcao = 4 / 3);
      },
    );
    stream.addListener(_ouvinte!);
  }

  void _pararDeOuvir() {
    if (_stream != null && _ouvinte != null) _stream!.removeListener(_ouvinte!);
  }

  @override
  void dispose() {
    _pararDeOuvir();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final proporcao = _proporcao;
    if (proporcao == null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(widget.raio)),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        var largura = c.maxWidth.isFinite ? c.maxWidth : 600.0;
        if (widget.larguraMaxima != null && largura > widget.larguraMaxima!) largura = widget.larguraMaxima!;
        var altura = largura / proporcao;
        if (widget.alturaMaxima != null && altura > widget.alturaMaxima!) {
          altura = widget.alturaMaxima!;
          largura = altura * proporcao;
        }
        final tamanho = Size(largura, altura);
        return Center(
          child: SizedBox.fromSize(
            size: tamanho,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.raio),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image(image: widget.imagem, fit: BoxFit.fill, gaplessPlayback: true),
                  if (widget.sobreposicao != null) widget.sobreposicao!(context, tamanho),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Visualizador em tela cheia: foto inteira (sem corte), zoom com pinça ou
/// roda do mouse, e setas/deslize entre as fotos.
Future<void> abrirFotoTelaCheia(
  BuildContext context,
  List<ImageProvider> imagens, {
  int inicial = 0,
  List<String?>? legendas,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (_, _, _) => _VisualizadorFotos(imagens: imagens, inicial: inicial, legendas: legendas),
      transitionsBuilder: (_, animacao, _, filho) => FadeTransition(opacity: animacao, child: filho),
    ),
  );
}

class _VisualizadorFotos extends StatefulWidget {
  final List<ImageProvider> imagens;
  final int inicial;
  final List<String?>? legendas;

  const _VisualizadorFotos({required this.imagens, required this.inicial, this.legendas});

  @override
  State<_VisualizadorFotos> createState() => _VisualizadorFotosState();
}

class _VisualizadorFotosState extends State<_VisualizadorFotos> {
  late final PageController _paginas = PageController(initialPage: widget.inicial);
  late int _atual = widget.inicial;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int delta) {
    final destino = (_atual + delta).clamp(0, widget.imagens.length - 1);
    _paginas.animateToPage(destino, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.imagens.length;
    final legenda = widget.legendas != null && _atual < widget.legendas!.length ? widget.legendas![_atual] : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _paginas,
              itemCount: total,
              onPageChanged: (i) => setState(() => _atual = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image(
                    image: widget.imagens[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const _FotoIndisponivel(escuro: true),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _BotaoRedondo(icone: Icons.close_rounded, dica: 'Fechar', aoTocar: () => Navigator.of(context).pop()),
            ),
            if (total > 1) ...[
              if (_atual > 0)
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _BotaoRedondo(icone: Icons.chevron_left_rounded, dica: 'Foto anterior', aoTocar: () => _ir(-1))),
                ),
              if (_atual < total - 1)
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(child: _BotaoRedondo(icone: Icons.chevron_right_rounded, dica: 'Próxima foto', aoTocar: () => _ir(1))),
                ),
            ],
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (legenda != null && legenda.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      child: Text(legenda, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  if (total > 1)
                    Text('${_atual + 1} de $total', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  final IconData icone;
  final String dica;
  final VoidCallback aoTocar;

  const _BotaoRedondo({required this.icone, required this.dica, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: dica,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: aoTocar,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icone, color: Colors.white, size: 22)),
        ),
      ),
    );
  }
}

class _FotoIndisponivel extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool escuro;

  const _FotoIndisponivel({this.icone = Icons.broken_image_outlined, this.texto = 'Foto indisponível', this.escuro = false});

  @override
  Widget build(BuildContext context) {
    final cor = escuro ? Colors.white70 : Colors.grey.shade500;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, color: cor),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(fontSize: 11, color: cor)),
        ],
      ),
    );
  }
}

/// Atalho: provider a partir de arquivo local ou URL (o que existir).
ImageProvider? imagemDe({String? url, ImageProvider? local}) {
  if (local != null) return local;
  if (url != null && url.trim().isNotEmpty) return StorageNetworkImage(url.trim());
  return null;
}

/// Para quem precisa esperar o tamanho real antes de desenhar algo.
Future<Size?> tamanhoRealDaImagem(BuildContext context, ImageProvider imagem) {
  final completer = Completer<Size?>();
  final stream = imagem.resolve(createLocalImageConfiguration(context));
  late ImageStreamListener ouvinte;
  ouvinte = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
      stream.removeListener(ouvinte);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      stream.removeListener(ouvinte);
    },
  );
  stream.addListener(ouvinte);
  return completer.future;
}
