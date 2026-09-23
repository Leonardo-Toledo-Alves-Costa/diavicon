import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remove metadados (EXIF, XMP, IPTC, comentários) de fotos JPEG antes do
/// upload.
///
/// POR QUE (LGPD): a foto da câmera traz no EXIF as coordenadas GPS, o
/// modelo e o número de série do aparelho e a hora exata. Esses dados não
/// fazem parte do registro técnico: as coordenadas que interessam ao laudo
/// já vão visíveis na marca d'água. Removemos o resto antes de o arquivo
/// sair do aparelho.
///
/// COMO: na maioria das fotos, os segmentos de metadados são cortados do
/// arquivo sem recodificar a imagem (sem perda de qualidade, rápido). Quando
/// o EXIF diz que a foto está girada, a rotação é aplicada nos pixels e a
/// imagem é recodificada, porque sem o EXIF o visualizador não saberia girar.
/// Outros formatos (PNG gerado pelo app, PDF) passam sem alteração.
abstract final class FotoMetadados {
  static bool ehJpeg(Uint8List bytes) =>
      bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8;

  /// Devolve os bytes sem metadados. Se não for JPEG, ou se algo falhar na
  /// leitura, devolve os próprios [bytes] (o mesmo objeto).
  static Future<Uint8List> limpar(Uint8List bytes) async {
    if (!ehJpeg(bytes)) return bytes;
    try {
      final orientacao = lerOrientacao(bytes);
      if (orientacao != null && orientacao != 1) {
        return await compute(_recodificarComRotacao, bytes);
      }
      return removerSegmentos(bytes);
    } catch (e) {
      debugPrint('[FotoMetadados] falha ao limpar (segue sem alteração): $e');
      return bytes;
    }
  }

  // Segmentos removidos: APP1 (EXIF e XMP), APP13 (IPTC/Photoshop),
  // APP12 (Ducky) e COM (comentário). Ficam APP0 (JFIF), APP2 (perfil de
  // cor ICC) e APP14 (Adobe), que afetam como a imagem é exibida.
  static const _remover = {0xE1, 0xEC, 0xED, 0xFE};

  static Uint8List removerSegmentos(Uint8List bytes) {
    final saida = BytesBuilder(copy: false);
    saida.add(const [0xFF, 0xD8]);
    var i = 2;
    while (i + 4 <= bytes.length) {
      if (bytes[i] != 0xFF) {
        throw const FormatException('JPEG sem marcador onde era esperado');
      }
      final marcador = bytes[i + 1];
      // Preenchimento (FF FF ...): avança.
      if (marcador == 0xFF) {
        i++;
        continue;
      }
      // Início dos dados da imagem: copia o resto como está.
      if (marcador == 0xDA) {
        saida.add(Uint8List.sublistView(bytes, i));
        return saida.toBytes();
      }
      final tamanho = (bytes[i + 2] << 8) | bytes[i + 3];
      final fim = i + 2 + tamanho;
      if (tamanho < 2 || fim > bytes.length) {
        throw const FormatException('Segmento JPEG com tamanho inválido');
      }
      if (!_remover.contains(marcador)) {
        saida.add(Uint8List.sublistView(bytes, i, fim));
      }
      i = fim;
    }
    throw const FormatException('JPEG sem início de dados (SOS)');
  }

  /// Lê a tag Orientation (0x0112) do EXIF, se houver.
  static int? lerOrientacao(Uint8List bytes) {
    var i = 2;
    while (i + 4 <= bytes.length && bytes[i] == 0xFF) {
      final marcador = bytes[i + 1];
      if (marcador == 0xDA) return null;
      final tamanho = (bytes[i + 2] << 8) | bytes[i + 3];
      if (marcador == 0xE1 && tamanho > 16) {
        final inicio = i + 4;
        final ehExif = bytes[inicio] == 0x45 && bytes[inicio + 1] == 0x78 &&
            bytes[inicio + 2] == 0x69 && bytes[inicio + 3] == 0x66;
        if (ehExif) return _orientacaoTiff(bytes, inicio + 6, i + 2 + tamanho);
      }
      i += 2 + tamanho;
    }
    return null;
  }

  static int? _orientacaoTiff(Uint8List b, int tiff, int limite) {
    if (tiff + 8 > limite) return null;
    final little = b[tiff] == 0x49; // "II"
    int u16(int p) => little ? b[p] | (b[p + 1] << 8) : (b[p] << 8) | b[p + 1];
    int u32(int p) => little
        ? b[p] | (b[p + 1] << 8) | (b[p + 2] << 16) | (b[p + 3] << 24)
        : (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
    final ifd = tiff + u32(tiff + 4);
    if (ifd + 2 > limite) return null;
    final n = u16(ifd);
    for (var k = 0; k < n; k++) {
      final e = ifd + 2 + k * 12;
      if (e + 12 > limite) return null;
      if (u16(e) == 0x0112) return u16(e + 8);
    }
    return null;
  }
}

Uint8List _recodificarComRotacao(Uint8List bytes) {
  final imagem = img.decodeJpg(bytes);
  if (imagem == null) return FotoMetadados.removerSegmentos(bytes);
  final girada = img.bakeOrientation(imagem);
  girada.exif = img.ExifData();
  return img.encodeJpg(girada, quality: 92);
}

/// Uploads que limpam os metadados das fotos antes de enviar.
extension UploadSemMetadados on StorageFileApi {
  Future<String> uploadSemMetadados(
    String path,
    File file, {
    FileOptions fileOptions = const FileOptions(),
  }) async {
    final bytes = await file.readAsBytes();
    final limpo = await FotoMetadados.limpar(bytes);
    if (identical(limpo, bytes)) {
      return upload(path, file, fileOptions: fileOptions);
    }
    return uploadBinary(path, limpo, fileOptions: _comTipoJpeg(fileOptions));
  }

  Future<String> uploadBinarySemMetadados(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
  }) async {
    final limpo = await FotoMetadados.limpar(data);
    return uploadBinary(
      path,
      limpo,
      fileOptions: identical(limpo, data) ? fileOptions : _comTipoJpeg(fileOptions),
    );
  }

  FileOptions _comTipoJpeg(FileOptions o) => FileOptions(
        cacheControl: o.cacheControl,
        upsert: o.upsert,
        contentType: o.contentType ?? 'image/jpeg',
      );
}
