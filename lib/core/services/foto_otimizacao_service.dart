import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;

// Gera a versão reduzida de uma foto para uso em relatório.
//
// Por que isso existe: o `image_picker` entrega a foto na resolução da
// câmera (~3000x4000, ~1,5MB mesmo com imageQuality 70) e essa era a imagem
// que subia pro Storage e ia parar no HTML do relatório. Num relatório de
// inspeção visual com 200+ fotos isso significa ~300MB de download e, no
// caminho PDF, a WebView do Android tendo que decodificar ~48MB de bitmap
// por foto antes de rasterizar — o que estoura a memória bem antes das 200.
//
// E é desperdício puro: numa A4, a galeria padrão (4 colunas, 140px de
// altura) renderiza cada foto com ~47x37mm, que a 300 DPI pede ~550px. A
// resolução extra é descartada pelo renderizador de qualquer jeito.
class FotoOtimizacaoService {
  // Maior lado da foto reduzida. 1280px cobre 300 DPI (padrão gráfico) até
  // ~108mm de largura impressa — folgado para a galeria de 4 colunas (47mm)
  // e suficiente para a de 2 colunas (95mm). Numa foto ocupando a largura
  // cheia da página (~190mm) fica em ~170 DPI: bom para leitura e
  // impressão, sem margem para zoom forense.
  //
  // Se um dia o requisito mudar, este é o único número a mexer: 2240
  // devolve 300 DPI em página cheia, ao custo de ~3x o peso por foto.
  static const int ladoMaximo = 1280;

  static const int qualidadeJpeg = 85;

  // Devolve um arquivo JPEG reduzido, ou a própria `foto` se ela já couber
  // no limite (ou se algo falhar — reduzir é otimização, nunca motivo para
  // perder o registro que o inspetor acabou de fazer em campo).
  static Future<File> reduzirParaRelatorio(File foto, {int ladoMaximo = FotoOtimizacaoService.ladoMaximo}) async {
    try {
      final bytes = await foto.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final larguraOriginal = descriptor.width;
      final alturaOriginal = descriptor.height;
      final maiorLado = larguraOriginal > alturaOriginal ? larguraOriginal : alturaOriginal;

      if (maiorLado <= ladoMaximo) {
        descriptor.dispose();
        buffer.dispose();
        return foto;
      }

      final escala = ladoMaximo / maiorLado;
      final larguraAlvo = (larguraOriginal * escala).round();
      final alturaAlvo = (alturaOriginal * escala).round();

      // instantiateCodec com targetWidth/targetHeight decodifica JÁ no
      // tamanho reduzido — o bitmap grande nunca chega a existir na RAM.
      final codec = await descriptor.instantiateCodec(targetWidth: larguraAlvo, targetHeight: alturaAlvo);
      final frame = await codec.getNextFrame();
      final imagemReduzida = frame.image;
      final rgba = await imagemReduzida.toByteData(format: ui.ImageByteFormat.rawRgba);

      // Só libera depois de decodificar: o codec lê os bytes do `buffer` de
      // forma preguiçosa, e descartá-lo antes do getNextFrame() faz a
      // decodificação falhar com "invalid image data".
      imagemReduzida.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (rgba == null) return foto;

      final jpeg = await codificarJpegRgba(rgba, larguraAlvo, alturaAlvo, qualidade: qualidadeJpeg);

      final destino = File('${Directory.systemTemp.path}/reduzida_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await destino.writeAsBytes(jpeg);
      debugPrint(
          '[FotoOtimizacao] ${larguraOriginal}x$alturaOriginal (${bytes.length ~/ 1024}KB) -> ${larguraAlvo}x$alturaAlvo (${jpeg.length ~/ 1024}KB)');
      return destino;
    } catch (e) {
      debugPrint('[FotoOtimizacao] falha ao reduzir (segue com a original): $e');
      return foto;
    }
  }

  // O encoder JPEG do pacote `image` é Dart puro: ~0,3–1s por foto de 1280px
  // num celular médio. Rodando na thread de UI isso congelava a tela durante
  // o salvamento (duas codificações por foto: redução + legenda), e com 20
  // fotos eram dezenas de segundos travado. Em outro isolate a tela segue
  // respondendo e o progresso aparece.
  static Future<Uint8List> codificarJpegRgba(ByteData rgba, int largura, int altura, {int qualidade = qualidadeJpeg}) {
    return compute(_codificarJpegRgba, (
      rgba: rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
      largura: largura,
      altura: altura,
      qualidade: qualidade,
    ));
  }
}

Uint8List _codificarJpegRgba(({Uint8List rgba, int largura, int altura, int qualidade}) a) {
  return img.encodeJpg(
    img.Image.fromBytes(
      width: a.largura,
      height: a.altura,
      bytes: a.rgba.buffer,
      bytesOffset: a.rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    ),
    quality: a.qualidade,
  );
}
