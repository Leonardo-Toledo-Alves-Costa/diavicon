import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors, Color;

import '../models/ultrassom_direto_model.dart';

// Compõe a foto "Pontos de leitura marcados" (foto_3) com os círculos
// numerados de cada ponto de medição desenhados por cima — até agora esses
// círculos só existiam como overlay ao vivo (widgets `Positioned` em
// `_buildInteractiveGrid`), nunca eram gravados na imagem de verdade, então
// a foto salva (e usada no relatório) saía sem nenhuma marcação. Roda em
// Canvas puro (sem BuildContext), mesma técnica de `UltrassomMapaCalorRenderer`.
class MarcacaoPontosRenderer {
  static Future<File> compor({
    required Uint8List bytesFotoBase,
    required List<PontoMedicaoUltrassomDiretoModel> medicoes,
  }) async {
    final codec = await ui.instantiateImageCodec(bytesFotoBase);
    final frame = await codec.getNextFrame();
    final imagemBase = frame.image;
    final largura = imagemBase.width.toDouble();
    final altura = imagemBase.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, largura, altura));
    canvas.drawImageRect(
      imagemBase,
      ui.Rect.fromLTWH(0, 0, largura, altura),
      ui.Rect.fromLTWH(0, 0, largura, altura),
      ui.Paint(),
    );

    // Raio proporcional ao tamanho da imagem — o overlay ao vivo usa 15px
    // fixos numa tela de celular; escala pelo mesmo fator aproximado
    // (imagem costuma ser bem maior que a tela).
    final raio = (largura / 22).clamp(14.0, 60.0);
    for (final medicao in medicoes) {
      final cx = medicao.posX * largura;
      final cy = medicao.posY * altura;
      final numeroVisual = medicao.nomePonto.replaceAll(RegExp(r'[^0-9]'), '');

      canvas.drawCircle(ui.Offset(cx, cy), raio, ui.Paint()..color = const Color(0xFFFFA726));
      canvas.drawCircle(
        ui.Offset(cx, cy),
        raio,
        ui.Paint()
          ..color = Colors.white
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = raio * 0.14,
      );

      final paragrafo = (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, fontSize: raio, fontWeight: ui.FontWeight.bold))
            ..pushStyle(ui.TextStyle(color: Colors.white, fontSize: raio, fontWeight: ui.FontWeight.bold))
            ..addText(numeroVisual.isNotEmpty ? numeroVisual : '?'))
          .build()
        ..layout(ui.ParagraphConstraints(width: raio * 2));
      canvas.drawParagraph(paragrafo, ui.Offset(cx - raio, cy - raio * 0.65));
    }

    final picture = recorder.endRecording();
    final imagemFinal = await picture.toImage(largura.round(), altura.round());
    final byteData = await imagemFinal.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final arquivo = File('${Directory.systemTemp.path}/pontos_marcados_${DateTime.now().millisecondsSinceEpoch}.png');
    await arquivo.writeAsBytes(bytes);
    return arquivo;
  }
}
