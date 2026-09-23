import 'dart:io';

import 'package:diavicon/core/services/foto_otimizacao_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('foto_otim_test');
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  // Gera um JPEG sintético com gradiente (conteúdo real, não chapado — um
  // JPEG de cor sólida comprime a quase nada e não testaria o peso).
  Future<File> jpegDe(int largura, int altura, String nome) async {
    final imagem = img.Image(width: largura, height: altura);
    for (var y = 0; y < altura; y++) {
      for (var x = 0; x < largura; x++) {
        imagem.setPixelRgb(x, y, x % 256, y % 256, (x * y) % 256);
      }
    }
    final arquivo = File('${temp.path}/$nome.jpg');
    await arquivo.writeAsBytes(img.encodeJpg(imagem, quality: 70));
    return arquivo;
  }

  test('reduz foto de câmera para o lado máximo, preservando a proporção', () async {
    final original = await jpegDe(3000, 4000, 'retrato');
    final reduzida = await FotoOtimizacaoService.reduzirParaRelatorio(original);

    final decodificada = img.decodeJpg(await reduzida.readAsBytes())!;
    expect(decodificada.height, FotoOtimizacaoService.ladoMaximo);
    expect(decodificada.width, 960); // 3000/4000 * 1280
    expect(reduzida.path, isNot(original.path));
  });

  test('funciona igual em paisagem (limita o maior lado, não a largura)', () async {
    final original = await jpegDe(4000, 3000, 'paisagem');
    final reduzida = await FotoOtimizacaoService.reduzirParaRelatorio(original);

    final decodificada = img.decodeJpg(await reduzida.readAsBytes())!;
    expect(decodificada.width, FotoOtimizacaoService.ladoMaximo);
    expect(decodificada.height, 960);
  });

  test('foto já pequena passa intacta, sem reencodar à toa', () async {
    final original = await jpegDe(800, 600, 'pequena');
    final reduzida = await FotoOtimizacaoService.reduzirParaRelatorio(original);

    expect(reduzida.path, original.path);
  });

  test('o peso cai o suficiente para um relatório de 200 fotos', () async {
    final original = await jpegDe(3000, 4000, 'peso');
    final reduzida = await FotoOtimizacaoService.reduzirParaRelatorio(original);

    final kbOriginal = original.lengthSync() / 1024;
    final kbReduzida = reduzida.lengthSync() / 1024;
    // ignore: avoid_print
    print('original ${kbOriginal.toStringAsFixed(0)}KB -> reduzida ${kbReduzida.toStringAsFixed(0)}KB '
        '(200 fotos: ${(kbOriginal * 200 / 1024).toStringAsFixed(0)}MB -> ${(kbReduzida * 200 / 1024).toStringAsFixed(0)}MB)');
    expect(kbReduzida, lessThan(kbOriginal));
  });
}
