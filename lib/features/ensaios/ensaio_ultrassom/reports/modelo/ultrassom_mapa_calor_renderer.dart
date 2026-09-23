import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors, Color, Matrix4, Offset, Size;

// Compõe a foto "Marcação da área" com a sobreposição do mapa de calor
// (perspectiva + IDW), pro campo `mapa_calor_us` do relatório — mesma
// matemática de `AnalisePontoUltrassomMapeamentoScreen` (perspectiva
// bilinear via 4 pontos + Inverse Distance Weighting, ver
// `HeatmapPainter`), só que direto num Canvas puro (sem widget tree/
// BuildContext, roda de dentro do Future desacoplado que gera o relatório —
// mesma técnica de `RelatorioChartRenderer`).
class _PontoCalor {
  final double x;
  final double y;
  final double valor;
  const _PontoCalor(this.x, this.y, this.valor);
}

class UltrassomMapaCalorRenderer {
  static const int _resolucao = 15;

  static Future<String?> compor({
    required String urlFotoBase,
    required List<({int linha, int coluna, double velocidade})> leituras,
    required double espacamentoX,
    required double espacamentoY,
    required double opacidade,
    required Offset p1,
    required Offset p2,
    required Offset p3,
    required Offset p4,
  }) async {
    if (leituras.isEmpty) return null;

    ui.Image imagemBase;
    try {
      final resposta = await StorageUrls.baixar(urlFotoBase);
      if (resposta.statusCode != 200) return null;
      final codec = await ui.instantiateImageCodec(resposta.bodyBytes);
      final frame = await codec.getNextFrame();
      imagemBase = frame.image;
    } catch (_) {
      return null;
    }

    final largura = imagemBase.width.toDouble();
    final altura = imagemBase.height.toDouble();
    final size = Size(largura, altura);

    final pontos = leituras.map((l) => _PontoCalor(l.coluna * espacamentoX, l.linha * espacamentoY, l.velocidade)).toList();
    final maxRealX = leituras.map((l) => l.coluna).reduce(max) * espacamentoX;
    final maxRealY = leituras.map((l) => l.linha).reduce(max) * espacamentoY;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));

    canvas.drawImageRect(
      imagemBase,
      ui.Rect.fromLTWH(0, 0, largura, altura),
      ui.Rect.fromLTWH(0, 0, largura, altura),
      ui.Paint(),
    );

    final matriz = _calcularMatrizPerspectiva(size, p1, p2, p3, p4);
    canvas.save();
    canvas.transform(matriz.storage);
    for (double i = 0; i < largura; i += _resolucao) {
      for (double j = 0; j < altura; j += _resolucao) {
        final realX = maxRealX == 0 ? 0.0 : (i / largura) * maxRealX;
        final realY = maxRealY == 0 ? 0.0 : (j / altura) * maxRealY;
        final valor = _calcularIDW(realX, realY, pontos);
        final cor = _corVelocidade(valor).withValues(alpha: opacidade);
        canvas.drawRect(ui.Rect.fromLTWH(i, j, _resolucao.toDouble(), _resolucao.toDouble()), ui.Paint()..color = cor);
      }
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final imagemFinal = await picture.toImage(largura.round(), altura.round());
    final byteData = await imagemFinal.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  // Mesma fórmula de homografia bilinear de `_calcularMatrizPerspectiva` em
  // `AnalisePontoUltrassomMapeamentoScreen` — 4 pontos de canto (fração
  // 0-1 da imagem) definem a transformação de perspectiva.
  static Matrix4 _calcularMatrizPerspectiva(Size size, Offset pt1, Offset pt2, Offset pt3, Offset pt4) {
    if (size.width == 0 || size.height == 0) return Matrix4.identity();
    final w = size.width, h = size.height;
    final x1 = pt1.dx * w, y1 = pt1.dy * h;
    final x2 = pt2.dx * w, y2 = pt2.dy * h;
    final x3 = pt3.dx * w, y3 = pt3.dy * h;
    final x4 = pt4.dx * w, y4 = pt4.dy * h;

    final dx1 = x2 - x3, dx2 = x4 - x3, dx3 = x1 - x2 + x3 - x4;
    final dy1 = y2 - y3, dy2 = y4 - y3, dy3 = y1 - y2 + y3 - y4;
    final det = dx1 * dy2 - dx2 * dy1;
    if (det == 0) return Matrix4.identity();

    final a13 = (dx3 * dy2 - dx2 * dy3) / det, a23 = (dx1 * dy3 - dx3 * dy1) / det;
    final a11 = x2 - x1 + a13 * x2, a21 = x4 - x1 + a23 * x4, a31 = x1;
    final a12 = y2 - y1 + a13 * y2, a22 = y4 - y1 + a23 * y4, a32 = y1;

    return Matrix4(a11 / w, a12 / w, 0, a13 / w, a21 / h, a22 / h, 0, a23 / h, 0, 0, 1, 0, a31, a32, 0, 1);
  }

  // Inverse Distance Weighting — mesmo algoritmo de `HeatmapPainter._calcularIDW`.
  static double _calcularIDW(double x, double y, List<_PontoCalor> pontos) {
    const p = 2.0;
    double num = 0.0, den = 0.0;
    for (final pt in pontos) {
      final d = sqrt(pow(x - pt.x, 2) + pow(y - pt.y, 2));
      if (d == 0) return pt.valor;
      final w = 1.0 / pow(d, p);
      num += w * pt.valor;
      den += w;
    }
    return den == 0 ? 0 : num / den;
  }

  // Mesma escala de cor (verde=rápido/melhor, vermelho=lento/pior) de
  // `AnalisePontoUltrassomMapeamentoScreen._corVelocidade`.
  static Color _corVelocidade(double v) {
    if (v <= 2000) return Color.lerp(Colors.red.shade900, Colors.red, (v / 2000).clamp(0.0, 1.0)) ?? Colors.red;
    if (v <= 3000) return Color.lerp(Colors.red, Colors.orange, (v - 2000) / 1000) ?? Colors.orange;
    if (v <= 3500) return Color.lerp(Colors.orange, Colors.yellow, (v - 3000) / 500) ?? Colors.yellow;
    if (v <= 4500) return Color.lerp(Colors.yellow, Colors.lightGreen, (v - 3500) / 1000) ?? Colors.lightGreen;
    final t = ((v - 4500) / 1000).clamp(0.0, 1.0);
    return Color.lerp(Colors.lightGreen, Colors.green.shade800, t) ?? Colors.green;
  }
}
