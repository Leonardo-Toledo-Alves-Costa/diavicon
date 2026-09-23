// Regras de upload de arquivos escolhidos pelo usuário (fotos, logos,
// comprovantes, plantas).
//
// POR QUE: os buckets são públicos. Antes, o app mantinha a extensão do
// arquivo do usuário no nome e deixava o tipo (Content-Type) ser deduzido
// dessa extensão. Um SVG ou HTML "disfarçado" de foto seria servido pelo
// domínio do Supabase como página ativa (XSS armazenado), e não havia limite
// de tamanho.
//
// O QUE ESTE ARQUIVO GARANTE:
//  * o tipo é decidido pelo CONTEÚDO (primeiros bytes), não pelo nome;
//  * só entram JPEG, PNG, WEBP e HEIC/HEIF (e PDF, quando o chamador permite);
//  * o Content-Type é enviado explicitamente, a partir do tipo detectado;
//  * o nome no Storage é gerado pelo app (<uuid>.<ext>) — texto digitado pelo
//    usuário nunca entra no caminho;
//  * limite de tamanho no aparelho (o bucket também limita, ver a migração
//    20260922140000_storage_limites_uploads.sql).
//
// Os buckets aceitam os mesmos tipos (allowed_mime_types): se um tipo novo
// for liberado aqui, precisa ser liberado lá também.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/foto_metadados.dart';

/// Arquivo recusado antes do envio. [toString] devolve a mensagem pronta
/// para mostrar ao usuário.
class ArquivoInvalidoException implements Exception {
  final String mensagem;
  const ArquivoInvalidoException(this.mensagem);

  @override
  String toString() => mensagem;
}

abstract final class UploadSeguro {
  /// Fotos: câmera de celular gera 3–12 MB; 15 MB dá folga.
  static const int maxImagemMb = 15;

  /// PDFs (plantas, comprovantes): plantas escaneadas passam de 20 MB.
  static const int maxPdfMb = 50;

  static const Set<String> extensoesImagem = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
  static const Set<String> extensoesImagemOuPdf = {...extensoesImagem, 'pdf'};

  static final Random _aleatorio = Random.secure();

  /// Content-Type de uma extensão aceita; null para qualquer outra.
  static String? contentTypeDe(String extensao) => switch (extensao.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        'pdf' => 'application/pdf',
        _ => null,
      };

  /// Extensão (minúscula, sem ponto) do nome ou caminho; '' quando não há.
  static String extensaoDe(String nomeOuCaminho) {
    final nome = nomeOuCaminho.split(RegExp(r'[/\\]')).last;
    final i = nome.lastIndexOf('.');
    return i < 0 ? '' : nome.substring(i + 1).toLowerCase();
  }

  /// Tipo real pelo conteúdo: 'jpg', 'png', 'webp', 'heic', 'heif', 'pdf' ou
  /// null (SVG, HTML, GIF, executável, texto…).
  static String? detectarTipo(Uint8List b) {
    bool comeca(List<int> assinatura, [int inicio = 0]) {
      if (b.length < inicio + assinatura.length) return false;
      for (var i = 0; i < assinatura.length; i++) {
        if (b[inicio + i] != assinatura[i]) return false;
      }
      return true;
    }

    if (comeca(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (comeca(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'png';
    // RIFF....WEBP
    if (comeca(const [0x52, 0x49, 0x46, 0x46]) && comeca(const [0x57, 0x45, 0x42, 0x50], 8)) return 'webp';
    // ISO-BMFF: ....ftyp<marca>
    if (comeca(const [0x66, 0x74, 0x79, 0x70], 4) && b.length >= 12) {
      final marca = String.fromCharCodes(b.sublist(8, 12));
      if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis'}.contains(marca)) return 'heic';
      if (const {'mif1', 'msf1'}.contains(marca)) return 'heif';
      return null;
    }
    // %PDF- nos primeiros 1024 bytes (a especificação tolera lixo antes).
    final limite = min(b.length, 1024);
    for (var i = 0; i + 5 <= limite; i++) {
      if (b[i] == 0x25 && comeca(const [0x25, 0x50, 0x44, 0x46, 0x2D], i)) return 'pdf';
    }
    return null;
  }

  /// Confere tamanho e extensão sem olhar o conteúdo (para quando só o nome e
  /// o tamanho estão disponíveis). Lança [ArquivoInvalidoException].
  static void validarArquivo({
    required int tamanhoBytes,
    required String extensao,
    Set<String> permitidas = extensoesImagem,
    int? maxMb,
  }) {
    final ext = extensao.toLowerCase();
    if (!permitidas.contains(ext) || contentTypeDe(ext) == null) {
      throw ArquivoInvalidoException(_mensagemTipo(permitidas));
    }
    final limiteMb = maxMb ?? (ext == 'pdf' ? maxPdfMb : maxImagemMb);
    if (tamanhoBytes <= 0) {
      throw const ArquivoInvalidoException('O arquivo está vazio.');
    }
    if (tamanhoBytes > limiteMb * 1024 * 1024) {
      final mb = (tamanhoBytes / (1024 * 1024)).toStringAsFixed(1);
      throw ArquivoInvalidoException('O arquivo tem $mb MB. O limite é $limiteMb MB.');
    }
  }

  /// Valida pelo CONTEÚDO e devolve a extensão a usar no nome ('jpg', 'png'…).
  /// Lança [ArquivoInvalidoException].
  static String validarConteudo(
    Uint8List bytes, {
    Set<String> permitidas = extensoesImagem,
    int? maxMb,
  }) {
    final tipo = detectarTipo(bytes);
    if (tipo == null || !permitidas.contains(tipo)) {
      throw ArquivoInvalidoException(_mensagemTipo(permitidas));
    }
    validarArquivo(tamanhoBytes: bytes.lengthInBytes, extensao: tipo, permitidas: permitidas, maxMb: maxMb);
    return tipo;
  }

  /// Nome gerado pelo app: `<prefixo><uuid v4>.<ext>`. O [prefixo] deve vir
  /// de ids/constantes do app (as políticas do bucket `avatars` exigem
  /// `<uid>_` no nome), nunca de texto digitado.
  static String nomeSeguro(String extensao, {String prefixo = ''}) =>
      '$prefixo${uuidV4()}.${extensao.toLowerCase()}';

  /// UUID v4 aleatório (sem depender de pacote externo).
  static String uuidV4() {
    final b = List<int>.generate(16, (_) => _aleatorio.nextInt(256));
    b[6] = (b[6] & 0x0F) | 0x40;
    b[8] = (b[8] & 0x3F) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String _mensagemTipo(Set<String> permitidas) => permitidas.contains('pdf')
      ? 'Formato não aceito. Envie uma foto (JPG, PNG, WEBP ou HEIC) ou um PDF.'
      : 'Formato não aceito. Envie uma foto em JPG, PNG, WEBP ou HEIC.';
}

/// Upload seguro: valida o conteúdo, gera o nome, limpa os metadados da foto
/// (ver [FotoMetadados]) e envia com o Content-Type do tipo detectado.
/// Devolve o caminho gravado no bucket (para `getPublicUrl`).
extension UploadSeguroStorage on StorageFileApi {
  Future<String> enviarBytesSeguro(
    String pasta,
    Uint8List bytes, {
    String prefixo = '',
    Set<String> permitidas = UploadSeguro.extensoesImagem,
    int? maxMb,
    FileOptions fileOptions = const FileOptions(),
  }) async {
    final ext = UploadSeguro.validarConteudo(bytes, permitidas: permitidas, maxMb: maxMb);
    final nome = UploadSeguro.nomeSeguro(ext, prefixo: prefixo);
    final caminho = pasta.isEmpty ? nome : '$pasta/$nome';
    final limpo = await FotoMetadados.limpar(bytes);
    await uploadBinary(
      caminho,
      limpo,
      fileOptions: FileOptions(
        cacheControl: fileOptions.cacheControl,
        upsert: fileOptions.upsert,
        contentType: UploadSeguro.contentTypeDe(ext),
      ),
    );
    return caminho;
  }

  Future<String> enviarArquivoSeguro(
    String pasta,
    File arquivo, {
    String prefixo = '',
    Set<String> permitidas = UploadSeguro.extensoesImagem,
    int? maxMb,
    FileOptions fileOptions = const FileOptions(),
  }) async {
    return enviarBytesSeguro(
      pasta,
      await arquivo.readAsBytes(),
      prefixo: prefixo,
      permitidas: permitidas,
      maxMb: maxMb,
      fileOptions: fileOptions,
    );
  }
}
