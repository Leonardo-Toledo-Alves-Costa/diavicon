import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors, Color;

// Gera gráficos do relatório como imagem PNG (base64), desenhando direto num
// Canvas via `dart:ui` — sem widget tree, sem BuildContext, sem Overlay.
// Mesma técnica já usada em `core/services/foto_watermark_service.dart` pra
// compor a legenda sobre a foto: funciona de dentro do Future desacoplado
// que gera o relatório em segundo plano (capturar um widget fora da tela
// via RepaintBoundary precisaria de um Overlay vivo da árvore de widgets do
// app e pode travar esperando um frame se o app for pra segundo plano).
class PontoGrafico {
  final double x;
  final double y;
  const PontoGrafico(this.x, this.y);
}

class SerieLinha {
  final String nome;
  final List<PontoGrafico> pontos;
  final Color cor;
  final bool preenchida;
  const SerieLinha({required this.nome, required this.pontos, required this.cor, this.preenchida = false});
}

class MarcadorVertical {
  final double x;
  final String rotulo;
  final Color cor;
  const MarcadorVertical({required this.x, required this.rotulo, required this.cor});
}

class GrupoBoxplot {
  final String rotulo;
  final double minimo;
  final double media;
  final double maximo;
  // Sobrepõe a cor da série só pra esse grupo — usado quando cada caixa
  // precisa de uma cor por um atributo diferente do agrupamento em si (ex:
  // "boxplot por elementos específicos" da Arrancamento: uma caixa por
  // elemento, colorida pelo TIPO do elemento). Null = usa a cor da série.
  final Color? cor;
  const GrupoBoxplot({required this.rotulo, required this.minimo, required this.media, required this.maximo, this.cor});
}

class SerieBoxplot {
  final String nome;
  final Color cor;
  final List<GrupoBoxplot> grupos;
  const SerieBoxplot({required this.nome, required this.cor, required this.grupos});
}

// Um segmento colorido dentro de uma barra empilhada (ex: a fração da tensão
// de arrancamento atribuída a um tipo de ruptura).
class SegmentoBarra {
  final String rotulo;
  final double valor;
  final Color cor;
  const SegmentoBarra({required this.rotulo, required this.valor, required this.cor});
}

class BarraSegmentadaGrupo {
  final String rotulo;
  final List<SegmentoBarra> segmentos;
  const BarraSegmentadaGrupo({required this.rotulo, required this.segmentos});
}

class BarraGrupo {
  final String rotulo;
  final double valor;
  // Sobrepõe a cor padrão só pra essa barra — usado quando cada barra
  // precisa de uma cor por um atributo próprio (ex: leitura aprovada/
  // reprovada da Esclerometria). Null = usa a cor padrão da função.
  final Color? cor;
  const BarraGrupo({required this.rotulo, required this.valor, this.cor});
}

// Faixa horizontal de fundo (ex: zona de risco) — desenhada atrás das
// barras pra indicar visualmente em qual zona cada valor cai.
class FaixaFundo {
  final double de;
  final double ate;
  final Color cor;
  final String? rotulo;
  const FaixaFundo({required this.de, required this.ate, required this.cor, this.rotulo});
}

class RelatorioChartRenderer {
  static const double _margemEsquerda = 60;
  static const double _margemDireita = 20;
  static const double _margemTopo = 32;
  static const double _margemBaixo = 46;

  // Plano cartesiano com (0,0) no CENTRO — pro "movimento em torno do eixo"
  // do Monitoramento de Fissuras: liga os pontos (X,Y) de cada medição em
  // ordem cronológica (mostra a trajetória da deformação) e destaca o
  // último ponto em vermelho — mesma ideia da tela ao vivo
  // (`_buildGraficoMovimentoXY`), só que em Canvas puro. Área sempre
  // quadrada e os dois eixos com a MESMA escala (±limite), senão a forma da
  // trajetória fica distorcida.
  static Future<String> planoXYComOrigem({
    required List<PontoGrafico> pontos,
    String tituloEixoX = 'Eixo X (mm)',
    String tituloEixoY = 'Eixo Y (mm)',
    double tamanho = 420,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, tamanho, tamanho));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, tamanho, tamanho), ui.Paint()..color = Colors.white);
    if (pontos.isEmpty) return _finalizar(recorder, tamanho, tamanho);

    final maiorAbs = pontos.expand((p) => [p.x.abs(), p.y.abs()]).reduce((a, b) => a > b ? a : b).clamp(0.2, double.infinity);
    final limite = maiorAbs * 1.4;

    final area = ui.Rect.fromLTWH(_margemEsquerda, _margemTopo, tamanho - _margemEsquerda - _margemDireita, tamanho - _margemTopo - _margemBaixo);

    double px(double x) => area.left + (x + limite) / (2 * limite) * area.width;
    double py(double y) => area.bottom - (y + limite) / (2 * limite) * area.height;

    // Grade + moldura, igual aos outros gráficos.
    canvas.drawRect(area, ui.Paint()..color = Colors.black12..style = ui.PaintingStyle.stroke..strokeWidth = 1);
    const passos = 4;
    for (var i = 0; i <= passos; i++) {
      final v = -limite + (2 * limite) * i / passos;
      canvas.drawLine(ui.Offset(area.left, py(v)), ui.Offset(area.right, py(v)), ui.Paint()..color = Colors.black12..strokeWidth = 0.5);
      canvas.drawLine(ui.Offset(px(v), area.top), ui.Offset(px(v), area.bottom), ui.Paint()..color = Colors.black12..strokeWidth = 0.5);
      canvas.drawParagraph(_paragrafo(v.toStringAsFixed(1), Colors.black45, 9, largura: 40, alinhamento: ui.TextAlign.right), ui.Offset(area.left - 46, py(v) - 6));
      canvas.drawParagraph(_paragrafo(v.toStringAsFixed(1), Colors.black45, 9, largura: 36, alinhamento: ui.TextAlign.center), ui.Offset(px(v) - 18, area.bottom + 6));
    }

    // Eixos cruzando em (0,0), mais grossos que a grade.
    canvas.drawLine(ui.Offset(area.left, py(0)), ui.Offset(area.right, py(0)), ui.Paint()..color = Colors.black45..strokeWidth = 1.2);
    canvas.drawLine(ui.Offset(px(0), area.top), ui.Offset(px(0), area.bottom), ui.Paint()..color = Colors.black45..strokeWidth = 1.2);

    // Trajetória conectando os pontos em ordem + um marcador em cada um.
    final path = ui.Path()..moveTo(px(pontos.first.x), py(pontos.first.y));
    for (final p in pontos.skip(1)) {
      path.lineTo(px(p.x), py(p.y));
    }
    canvas.drawPath(path, ui.Paint()..color = const Color(0xFFFFA726)..style = ui.PaintingStyle.stroke..strokeWidth = 2);
    for (final p in pontos) {
      canvas.drawCircle(ui.Offset(px(p.x), py(p.y)), 3, ui.Paint()..color = const Color(0xFFFFA726));
    }
    // Último ponto em destaque (vermelho, maior) — leitura mais recente.
    final ultimo = pontos.last;
    canvas.drawCircle(ui.Offset(px(ultimo.x), py(ultimo.y)), 6, ui.Paint()..color = Colors.red);

    canvas.drawParagraph(_paragrafo(tituloEixoX, Colors.black54, 10, largura: area.width, alinhamento: ui.TextAlign.center), ui.Offset(area.left, area.bottom + 24));
    canvas.save();
    canvas.translate(14, area.center.dy + 30);
    canvas.rotate(-1.5708);
    canvas.drawParagraph(_paragrafo(tituloEixoY, Colors.black54, 10), ui.Offset.zero);
    canvas.restore();

    return _finalizar(recorder, tamanho, tamanho);
  }

  // Curva(s) num eixo X/Y contínuo — usado pro avanço da frente de
  // carbonatação (curva + faixa de cobrimento + marcadores de idade/falha) e
  // pra estimativa de probabilidade de despassivação (curva 0-100%).
  static Future<String> linhaComFaixa({
    required List<SerieLinha> series,
    List<MarcadorVertical> marcadores = const [],
    String tituloEixoX = '',
    String tituloEixoY = '',
    double largura = 640,
    double altura = 340,
    // Inverte o eixo Y (valores maiores desenhados mais pra baixo) — usado
    // pro gráfico de deslocamento x carga da Prova de Carga Estática, que
    // segue a mesma convenção de `NumericAxis(isInversed: true)` já usada em
    // `analise_prova_carga_screen.dart` (deslocamento cresce pra baixo).
    bool inverterEixoY = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, largura, altura), ui.Paint()..color = Colors.white);

    final todosPontos = series.expand((s) => s.pontos).toList();
    if (todosPontos.isEmpty) return _finalizar(recorder, largura, altura);

    final minX = todosPontos.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    final maxXBase = todosPontos.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    final maxX = maxXBase <= minX ? minX + 1 : maxXBase;
    final maxYBase = todosPontos.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    const minY = 0.0;
    final maxY = maxYBase <= minY ? minY + 1 : maxYBase * 1.1;

    final area = ui.Rect.fromLTWH(
      _margemEsquerda,
      _margemTopo,
      largura - _margemEsquerda - _margemDireita,
      altura - _margemTopo - _margemBaixo,
    );

    double px(double x) => area.left + (x - minX) / (maxX - minX) * area.width;
    double py(double y) {
      final fracao = (y - minY) / (maxY - minY);
      return inverterEixoY ? area.top + fracao * area.height : area.bottom - fracao * area.height;
    }

    _desenharGradeEEixos(canvas, area, minX, maxX, minY, maxY, px, py, tituloEixoX, tituloEixoY);

    for (final serie in series) {
      if (serie.pontos.isEmpty) continue;
      final ordenados = [...serie.pontos]..sort((a, b) => a.x.compareTo(b.x));
      final path = ui.Path()..moveTo(px(ordenados.first.x), py(ordenados.first.y));
      for (final p in ordenados.skip(1)) {
        path.lineTo(px(p.x), py(p.y));
      }
      if (serie.preenchida) {
        final areaPath = ui.Path.from(path)
          ..lineTo(px(ordenados.last.x), py(minY))
          ..lineTo(px(ordenados.first.x), py(minY))
          ..close();
        canvas.drawPath(areaPath, ui.Paint()..color = serie.cor.withValues(alpha: 0.15));
      }
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = serie.cor
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    for (final marcador in marcadores) {
      final x = px(marcador.x);
      canvas.drawLine(
        ui.Offset(x, area.top),
        ui.Offset(x, area.bottom),
        ui.Paint()
          ..color = marcador.cor
          ..strokeWidth = 1.4
          ..style = ui.PaintingStyle.stroke,
      );
      canvas.drawParagraph(_paragrafo(marcador.rotulo, marcador.cor, 10), ui.Offset(x + 4, area.top + 2));
    }

    _desenharLegenda(canvas, area, [for (final s in series) MapEntry(s.nome, s.cor)]);

    return _finalizar(recorder, largura, altura);
  }

  // Uma barra "flutuante" (mínimo–máximo com marcador na média) por grupo —
  // mesma aproximação de boxplot já usada no gerador de relatório existente
  // de Carbonatação (`carbonatacao_report_service.dart`), não é um boxplot
  // de quartis de verdade.
  static Future<String> boxplotPorGrupo({
    required List<SerieBoxplot> series,
    String tituloEixoY = '',
    double largura = 720,
    double altura = 400,
    // Substitui a legenda padrão (nome+cor de cada série) — usado quando a
    // cor de cada caixa vem de `GrupoBoxplot.cor` em vez da série (ver
    // "boxplot por elementos específicos" da Arrancamento).
    List<MapEntry<String, Color>>? legendaOverride,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, largura, altura), ui.Paint()..color = Colors.white);

    final rotulos = series.isNotEmpty ? series.first.grupos.map((g) => g.rotulo).toList() : <String>[];
    if (rotulos.isEmpty) return _finalizar(recorder, largura, altura);

    // Eixo dinâmico (não fixo em 0): séries com valores só negativos (ex:
    // potencial de corrosão em mV) precisam de minY negativo, senão as
    // barras são desenhadas inteiramente fora da área visível do canvas —
    // ficam "geradas" mas invisíveis no PDF. Dados só positivos (Carbonatação/
    // Resistividade) continuam com minY=0, mesmo comportamento de antes.
    final todosValores = series.expand((s) => s.grupos.expand((g) => [g.minimo, g.media, g.maximo])).toList();
    final valorMinimo = todosValores.isEmpty ? 0.0 : todosValores.reduce((a, b) => a < b ? a : b);
    final valorMaximo = todosValores.isEmpty ? 1.0 : todosValores.reduce((a, b) => a > b ? a : b);
    final minY = valorMinimo < 0 ? valorMinimo * 1.15 : 0.0;
    var maxY = valorMaximo > 0 ? valorMaximo * 1.15 : 0.0;
    if (maxY <= minY) maxY = minY + 1;

    // Reserva um pouco mais de altura embaixo pro rótulo de cada grupo (pode
    // quebrar em até 2 linhas quando o nome do local/elemento é longo).
    final area = ui.Rect.fromLTWH(
      _margemEsquerda,
      _margemTopo,
      largura - _margemEsquerda - _margemDireita,
      altura - _margemTopo - _margemBaixo - 16,
    );

    double py(double y) => area.bottom - (y - minY) / (maxY - minY) * area.height;

    _desenharGradeYComRotulos(canvas, area, minY, maxY, py, tituloEixoY);
    canvas.drawLine(area.bottomLeft, area.bottomRight, ui.Paint()..color = Colors.black38..strokeWidth = 1);

    final larguraGrupo = area.width / rotulos.length;
    final larguraBarra = (larguraGrupo * 0.7 / series.length).clamp(10.0, 56.0);
    const espacoEntreBarras = 6.0;

    for (var g = 0; g < rotulos.length; g++) {
      final centroGrupo = area.left + larguraGrupo * (g + 0.5);

      // Linha separadora leve entre grupos — ajuda a ler quando há várias categorias.
      if (g > 0) {
        final xSep = area.left + larguraGrupo * g;
        canvas.drawLine(ui.Offset(xSep, area.top), ui.Offset(xSep, area.bottom), ui.Paint()..color = Colors.black12..strokeWidth = 0.5);
      }

      final larguraTotalBarras = series.length * larguraBarra + (series.length - 1) * espacoEntreBarras;
      var x = centroGrupo - larguraTotalBarras / 2;

      for (var s = 0; s < series.length; s++) {
        final grupo = series[s].grupos[g];
        final corBarra = grupo.cor ?? series[s].cor;
        final rect = ui.Rect.fromLTRB(x, py(grupo.maximo), x + larguraBarra, py(grupo.minimo));

        // Barra "flutuante" preenchida (mínimo–máximo) com borda — bem mais
        // legível que só uma linha fina com um ponto no meio.
        canvas.drawRect(rect, ui.Paint()..color = corBarra.withValues(alpha: 0.28));
        canvas.drawRect(
          rect,
          ui.Paint()
            ..color = corBarra
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );

        // Linha da média atravessando a barra inteira.
        final yMedia = py(grupo.media);
        canvas.drawLine(
          ui.Offset(x, yMedia),
          ui.Offset(x + larguraBarra, yMedia),
          ui.Paint()
            ..color = corBarra
            ..strokeWidth = 3,
        );

        x += larguraBarra + espacoEntreBarras;
      }

      final rotuloParagrafo = _paragrafo(rotulos[g], Colors.black87, 10, largura: larguraGrupo - 4, alinhamento: ui.TextAlign.center);
      canvas.drawParagraph(rotuloParagrafo, ui.Offset(centroGrupo - (larguraGrupo - 4) / 2, area.bottom + 8));
    }

    _desenharLegenda(canvas, area, legendaOverride ?? [for (final s in series) MapEntry(s.nome, s.cor)]);

    return _finalizar(recorder, largura, altura);
  }

  // Barras empilhadas por segmentos coloridos (ex: a tensão de arrancamento
  // de cada leitura/elemento, dividida proporcionalmente por tipo de
  // ruptura) — mesma ideia do `StackedColumnSeries` já usado nas telas de
  // análise de Arrancamento, mas em Canvas puro.
  static Future<String> barrasSegmentadas({
    required List<BarraSegmentadaGrupo> grupos,
    String tituloEixoY = '',
    double largura = 720,
    double altura = 400,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, largura, altura), ui.Paint()..color = Colors.white);

    if (grupos.isEmpty) return _finalizar(recorder, largura, altura);

    const minY = 0.0;
    final totais = grupos.map((g) => g.segmentos.fold(0.0, (a, s) => a + s.valor)).toList();
    final maxTotal = totais.isEmpty ? 0.0 : totais.reduce((a, b) => a > b ? a : b);
    final maxY = maxTotal <= 0 ? 1.0 : maxTotal * 1.15;

    final area = ui.Rect.fromLTWH(
      _margemEsquerda,
      _margemTopo,
      largura - _margemEsquerda - _margemDireita,
      altura - _margemTopo - _margemBaixo - 16,
    );

    double py(double y) => area.bottom - (y - minY) / (maxY - minY) * area.height;

    _desenharGradeYComRotulos(canvas, area, minY, maxY, py, tituloEixoY);
    canvas.drawLine(area.bottomLeft, area.bottomRight, ui.Paint()..color = Colors.black38..strokeWidth = 1);

    final larguraGrupo = area.width / grupos.length;
    final larguraBarra = (larguraGrupo * 0.6).clamp(10.0, 64.0);
    final legendaItens = <String, Color>{};

    for (var g = 0; g < grupos.length; g++) {
      final centroGrupo = area.left + larguraGrupo * (g + 0.5);
      var yAcumulado = 0.0;
      for (final segmento in grupos[g].segmentos) {
        if (segmento.valor <= 0) continue;
        final rect = ui.Rect.fromLTRB(
          centroGrupo - larguraBarra / 2,
          py(yAcumulado + segmento.valor),
          centroGrupo + larguraBarra / 2,
          py(yAcumulado),
        );
        canvas.drawRect(rect, ui.Paint()..color = segmento.cor);
        canvas.drawRect(rect, ui.Paint()..color = Colors.white.withValues(alpha: 0.5)..style = ui.PaintingStyle.stroke..strokeWidth = 0.6);
        yAcumulado += segmento.valor;
        legendaItens[segmento.rotulo] = segmento.cor;
      }

      final rotuloParagrafo = _paragrafo(grupos[g].rotulo, Colors.black87, 10, largura: larguraGrupo - 4, alinhamento: ui.TextAlign.center);
      canvas.drawParagraph(rotuloParagrafo, ui.Offset(centroGrupo - (larguraGrupo - 4) / 2, area.bottom + 8));
    }

    _desenharLegenda(canvas, area, legendaItens.entries.map((e) => MapEntry(e.key, e.value)).toList());

    return _finalizar(recorder, largura, altura);
  }

  // Uma barra por grupo (cor por barra, via `BarraGrupo.cor`) com uma linha
  // horizontal tracejada marcando a média — ex: índice esclerométrico por
  // leitura da Esclerometria (barra aprovada/reprovada + linha da média),
  // igual à tela de análise por ponto já existente.
  static Future<String> barrasComMediaHorizontal({
    required List<BarraGrupo> grupos,
    required double media,
    String rotuloMedia = 'Média',
    String tituloEixoY = '',
    Color corPadrao = Colors.blueGrey,
    Color corLinhaMedia = const Color(0xFF1B2A4A),
    double largura = 720,
    double altura = 400,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, largura, altura), ui.Paint()..color = Colors.white);

    if (grupos.isEmpty) return _finalizar(recorder, largura, altura);

    final valoresGrupos = grupos.map((g) => g.valor).toList();
    const minY = 0.0;
    final maxYBase = [...valoresGrupos, media].reduce((a, b) => a > b ? a : b);
    final maxY = maxYBase <= 0 ? 1.0 : maxYBase * 1.15;

    final area = ui.Rect.fromLTWH(
      _margemEsquerda,
      _margemTopo,
      largura - _margemEsquerda - _margemDireita,
      altura - _margemTopo - _margemBaixo - 16,
    );

    double py(double y) => area.bottom - (y - minY) / (maxY - minY) * area.height;

    _desenharGradeYComRotulos(canvas, area, minY, maxY, py, tituloEixoY);
    canvas.drawLine(area.bottomLeft, area.bottomRight, ui.Paint()..color = Colors.black38..strokeWidth = 1);

    final larguraGrupo = area.width / grupos.length;
    final larguraBarra = (larguraGrupo * 0.6).clamp(10.0, 64.0);

    for (var g = 0; g < grupos.length; g++) {
      final centroGrupo = area.left + larguraGrupo * (g + 0.5);
      final corBarra = grupos[g].cor ?? corPadrao;
      final rect = ui.Rect.fromLTRB(centroGrupo - larguraBarra / 2, py(grupos[g].valor), centroGrupo + larguraBarra / 2, area.bottom);
      canvas.drawRect(rect, ui.Paint()..color = corBarra);
      canvas.drawRect(rect, ui.Paint()..color = corBarra.withValues(alpha: 0.8)..style = ui.PaintingStyle.stroke..strokeWidth = 1);

      final rotuloParagrafo = _paragrafo(grupos[g].rotulo, Colors.black87, 10, largura: larguraGrupo - 4, alinhamento: ui.TextAlign.center);
      canvas.drawParagraph(rotuloParagrafo, ui.Offset(centroGrupo - (larguraGrupo - 4) / 2, area.bottom + 8));
    }

    // Linha horizontal tracejada da média, sobre as barras.
    final yMedia = py(media);
    const tracoComprimento = 6.0;
    const tracoEspaco = 4.0;
    var x = area.left;
    while (x < area.right) {
      final fim = (x + tracoComprimento).clamp(area.left, area.right);
      canvas.drawLine(ui.Offset(x, yMedia), ui.Offset(fim, yMedia), ui.Paint()..color = corLinhaMedia..strokeWidth = 1.6);
      x += tracoComprimento + tracoEspaco;
    }
    canvas.drawParagraph(
      _paragrafo('$rotuloMedia: ${media.toStringAsFixed(1)}', corLinhaMedia, 10, largura: 140, alinhamento: ui.TextAlign.right),
      ui.Offset(area.right - 140, yMedia - 14),
    );

    return _finalizar(recorder, largura, altura);
  }

  // Uma barra por grupo, com faixas horizontais de fundo coloridas (ex: as
  // zonas de risco de corrosão da Resistividade) — mostra visualmente em
  // qual zona cada grupo cai, sem precisar de legenda numérica.
  static Future<String> barrasComFaixas({
    required List<BarraGrupo> grupos,
    List<FaixaFundo> faixas = const [],
    String tituloEixoY = '',
    Color corBarra = Colors.blueGrey,
    double largura = 720,
    double altura = 400,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, largura, altura), ui.Paint()..color = Colors.white);

    if (grupos.isEmpty) return _finalizar(recorder, largura, altura);

    final valoresGrupos = grupos.map((g) => g.valor).toList();
    final valoresFaixas = faixas.expand((f) => [f.de, f.ate]).toList();
    const minY = 0.0;
    final maxYBase = [...valoresGrupos, ...valoresFaixas].reduce((a, b) => a > b ? a : b);
    final maxY = maxYBase <= 0 ? 1.0 : maxYBase * 1.1;

    final area = ui.Rect.fromLTWH(
      _margemEsquerda,
      _margemTopo,
      largura - _margemEsquerda - _margemDireita,
      altura - _margemTopo - _margemBaixo - 16,
    );

    double py(double y) => area.bottom - (y - minY) / (maxY - minY) * area.height;

    // Faixas de fundo primeiro (atrás de tudo).
    for (final faixa in faixas) {
      final topo = py(faixa.ate.clamp(minY, maxY));
      final base = py(faixa.de.clamp(minY, maxY));
      canvas.drawRect(ui.Rect.fromLTRB(area.left, topo, area.right, base), ui.Paint()..color = faixa.cor.withValues(alpha: 0.18));
    }

    _desenharGradeYComRotulos(canvas, area, minY, maxY, py, tituloEixoY);
    canvas.drawLine(area.bottomLeft, area.bottomRight, ui.Paint()..color = Colors.black38..strokeWidth = 1);

    final larguraGrupo = area.width / grupos.length;
    final larguraBarra = (larguraGrupo * 0.6).clamp(10.0, 64.0);

    for (var g = 0; g < grupos.length; g++) {
      final centroGrupo = area.left + larguraGrupo * (g + 0.5);
      final rect = ui.Rect.fromLTRB(centroGrupo - larguraBarra / 2, py(grupos[g].valor), centroGrupo + larguraBarra / 2, area.bottom);
      canvas.drawRect(rect, ui.Paint()..color = corBarra);
      canvas.drawRect(rect, ui.Paint()..color = corBarra.withValues(alpha: 0.8)..style = ui.PaintingStyle.stroke..strokeWidth = 1);

      final rotuloParagrafo = _paragrafo(grupos[g].rotulo, Colors.black87, 10, largura: larguraGrupo - 4, alinhamento: ui.TextAlign.center);
      canvas.drawParagraph(rotuloParagrafo, ui.Offset(centroGrupo - (larguraGrupo - 4) / 2, area.bottom + 8));
    }

    if (faixas.any((f) => f.rotulo != null)) {
      _desenharLegenda(canvas, area, [for (final f in faixas) if (f.rotulo != null) MapEntry(f.rotulo!, f.cor)]);
    }

    return _finalizar(recorder, largura, altura);
  }

  static void _desenharGradeEEixos(
    ui.Canvas canvas,
    ui.Rect area,
    double minX,
    double maxX,
    double minY,
    double maxY,
    double Function(double) px,
    double Function(double) py,
    String tituloEixoX,
    String tituloEixoY,
  ) {
    canvas.drawLine(area.bottomLeft, area.bottomRight, ui.Paint()..color = Colors.black38..strokeWidth = 1);
    canvas.drawLine(area.bottomLeft, area.topLeft, ui.Paint()..color = Colors.black38..strokeWidth = 1);

    const passos = 4;
    for (var i = 0; i <= passos; i++) {
      final y = minY + (maxY - minY) * i / passos;
      final yPix = py(y);
      canvas.drawLine(ui.Offset(area.left, yPix), ui.Offset(area.right, yPix), ui.Paint()..color = Colors.black12..strokeWidth = 0.6);
      canvas.drawParagraph(
        _paragrafo(y.toStringAsFixed(1), Colors.black54, 9, largura: 44, alinhamento: ui.TextAlign.right),
        ui.Offset(area.left - 50, yPix - 6),
      );
    }
    for (var i = 0; i <= passos; i++) {
      final x = minX + (maxX - minX) * i / passos;
      canvas.drawParagraph(
        _paragrafo(x.toStringAsFixed(0), Colors.black54, 9, largura: 36, alinhamento: ui.TextAlign.center),
        ui.Offset(px(x) - 18, area.bottom + 6),
      );
    }
    if (tituloEixoY.isNotEmpty) {
      canvas.save();
      canvas.translate(14, area.center.dy + 30);
      canvas.rotate(-1.5708);
      canvas.drawParagraph(_paragrafo(tituloEixoY, Colors.black54, 10), ui.Offset.zero);
      canvas.restore();
    }
    if (tituloEixoX.isNotEmpty) {
      canvas.drawParagraph(
        _paragrafo(tituloEixoX, Colors.black54, 10, largura: area.width, alinhamento: ui.TextAlign.center),
        ui.Offset(area.left, area.bottom + 22),
      );
    }
  }

  static void _desenharGradeYComRotulos(
      ui.Canvas canvas, ui.Rect area, double minY, double maxY, double Function(double) py, String titulo) {
    const passos = 4;
    for (var i = 0; i <= passos; i++) {
      final y = minY + (maxY - minY) * i / passos;
      final yPix = py(y);
      canvas.drawLine(ui.Offset(area.left, yPix), ui.Offset(area.right, yPix), ui.Paint()..color = Colors.black12..strokeWidth = 0.6);
      canvas.drawParagraph(
        _paragrafo(y.toStringAsFixed(1), Colors.black54, 9, largura: 44, alinhamento: ui.TextAlign.right),
        ui.Offset(area.left - 50, yPix - 6),
      );
    }
    canvas.drawLine(area.bottomLeft, area.topLeft, ui.Paint()..color = Colors.black38..strokeWidth = 1);
    if (titulo.isNotEmpty) {
      canvas.save();
      canvas.translate(14, area.center.dy + 30);
      canvas.rotate(-1.5708);
      canvas.drawParagraph(_paragrafo(titulo, Colors.black54, 10), ui.Offset.zero);
      canvas.restore();
    }
  }

  static void _desenharLegenda(ui.Canvas canvas, ui.Rect area, List<MapEntry<String, Color>> itens) {
    var x = area.left;
    final y = area.top - 20;
    for (final item in itens) {
      canvas.drawRect(ui.Rect.fromLTWH(x, y, 10, 10), ui.Paint()..color = item.value);
      canvas.drawParagraph(_paragrafo(item.key, Colors.black87, 10), ui.Offset(x + 14, y - 2));
      x += 14 + (item.key.length * 6.0) + 18;
    }
  }

  static ui.Paragraph _paragrafo(
    String texto,
    Color cor,
    double tamanho, {
    double largura = 120,
    ui.TextAlign alinhamento = ui.TextAlign.left,
  }) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: alinhamento, fontSize: tamanho, maxLines: 2, ellipsis: '…'))
      ..pushStyle(ui.TextStyle(color: cor, fontSize: tamanho))
      ..addText(texto);
    return builder.build()..layout(ui.ParagraphConstraints(width: largura));
  }

  static Future<String> _finalizar(ui.PictureRecorder recorder, double largura, double altura) async {
    final picture = recorder.endRecording();
    final imagem = await picture.toImage(largura.round(), altura.round());
    final byteData = await imagem.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }
}
