import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Colors, Color;
import 'package:gal/gal.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/empresa/models/timestamp_foto_padrao_model.dart';
import 'foto_otimizacao_service.dart';

class FotoWatermarkService {
  // Resolve os dados reais (nomes, localização) que entram na legenda, consultando
  // apenas o que o padrão da empresa realmente usa. Deixa em branco (e a linha
  // correspondente é omitida) o que não puder ser resolvido.
  static Future<WatermarkFotoContexto> resolverContexto({
    required TimestampFotoPadraoModel padrao,
    required SupabaseClient supabase,
    String? projetoId,
    String? estruturaId,
    String? sistemaId,
    String? elementoId,
    String? nomeLocal,
    String? nomeTipoElemento,
    // Usado quando o chamador já tem o nome do elemento específico resolvido
    // (ex: tela de ensaios) em vez do id (ex: registro de inspeção visual).
    String? nomeElementoEspecificoDireto,
    String? nomeUsuario,
    String? nomeEmpresa,
    String? logoUrl,
    String? descricaoImagem,
  }) async {
    String? nomeProjeto;
    String? nomeEstrutura;
    String? nomeConjuntoEstrutural;
    String? nomeSistema;
    String? nomeElementoEspecifico = nomeElementoEspecificoDireto;

    try {
      if (padrao.projeto && projetoId != null) {
        final r = await supabase.from('projetos').select('nome').eq('id', projetoId).maybeSingle();
        nomeProjeto = r?['nome'] as String?;
      }
      if ((padrao.estrutura || padrao.conjuntoEstrutural) && estruturaId != null) {
        final r = await supabase
            .from('estruturas')
            .select('nome, conjuntos_estruturais(nome)')
            .eq('id', estruturaId)
            .maybeSingle();
        if (padrao.estrutura) nomeEstrutura = r?['nome'] as String?;
        if (padrao.conjuntoEstrutural) {
          final conjunto = r?['conjuntos_estruturais'] as Map<String, dynamic>?;
          nomeConjuntoEstrutural = conjunto?['nome'] as String?;
        }
      }
      if (padrao.sistema && sistemaId != null) {
        final r = await supabase.from('sistemas_habitacionais').select('nome').eq('id', sistemaId).maybeSingle();
        nomeSistema = r?['nome'] as String?;
      }
      if (padrao.elemento && elementoId != null) {
        final r = await supabase.from('elementos_estruturais').select('nome').eq('id', elementoId).maybeSingle();
        nomeElementoEspecifico = (r?['nome'] as String?) ?? nomeElementoEspecifico;
      }
    } catch (e) {
      // Best-effort: se a busca falhar, a linha correspondente fica de fora da legenda.
      debugPrint('[FotoWatermark] falha ao resolver nomes de projeto/estrutura/sistema/elemento: $e');
    }

    double? latitude;
    double? longitude;
    if (padrao.latitudeLongitude) {
      final posicao = await _tentarObterLocalizacao();
      latitude = posicao?.latitude;
      longitude = posicao?.longitude;
    }

    return WatermarkFotoContexto(
      nomeProjeto: nomeProjeto,
      nomeEstrutura: nomeEstrutura,
      nomeConjuntoEstrutural: nomeConjuntoEstrutural,
      nomeLocal: nomeLocal,
      nomeSistema: nomeSistema,
      nomeTipoElemento: padrao.tipoElemento ? nomeTipoElemento : null,
      nomeElementoEspecifico: nomeElementoEspecifico,
      nomeEmpresa: nomeEmpresa,
      logoUrl: logoUrl,
      nomeUsuario: nomeUsuario,
      latitude: latitude,
      longitude: longitude,
      descricaoImagem: descricaoImagem,
      capturadoEm: DateTime.now(),
    );
  }

  static Future<Position?> _tentarObterLocalizacao() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
      );
    } catch (_) {
      return null;
    }
  }

  // Salva uma cópia da foto tirada com a câmera na galeria do celular. Best-effort:
  // nunca lança exceção (falha de permissão/plataforma apenas é ignorada).
  static Future<bool> salvarNaGaleriaDoDispositivo(File arquivo) async {
    try {
      final acesso = await Gal.requestAccess();
      if (!acesso) return false;
      await Gal.putImage(arquivo.path, album: 'Diavicon');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Color corParaTexto(String cor) {
    switch (cor) {
      case 'Preto':
        return Colors.black;
      case 'Amarelo':
        return Colors.amber;
      case 'Vermelho':
        return Colors.redAccent;
      case 'Branco':
      default:
        return Colors.white;
    }
  }

  static String _dois(int v) => v.toString().padLeft(2, '0');

  static String formatarData(DateTime d) => '${_dois(d.day)}/${_dois(d.month)}/${d.year}';

  static String formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

  // Monta as linhas de texto na mesma ordem/composição usadas tanto na prévia
  // da tela de configuração quanto na gravação real sobre a foto:
  // Data e hora / Nome do projeto / Conjunto Estrutural | Estrutura | Local /
  // Sistema | Tipo de elemento | Elemento específico / Lat e Long / Descrição / Empresa | Usuário.
  static List<String> montarLinhas(TimestampFotoPadraoModel padrao, WatermarkFotoContexto ctx) {
    final linhas = <String>[];

    final dataHora = <String>[];
    final capturadoEm = ctx.capturadoEm ?? DateTime.now();
    if (padrao.data) dataHora.add(formatarData(capturadoEm));
    if (padrao.hora) dataHora.add(formatarHora(capturadoEm));
    if (dataHora.isNotEmpty) linhas.add(dataHora.join(' '));

    if (padrao.projeto && (ctx.nomeProjeto?.isNotEmpty ?? false)) {
      linhas.add(ctx.nomeProjeto!);
    }

    final estruturaGrupo = <String>[];
    if (padrao.conjuntoEstrutural && (ctx.nomeConjuntoEstrutural?.isNotEmpty ?? false)) {
      estruturaGrupo.add(ctx.nomeConjuntoEstrutural!);
    }
    if (padrao.estrutura && (ctx.nomeEstrutura?.isNotEmpty ?? false)) estruturaGrupo.add(ctx.nomeEstrutura!);
    if (padrao.local && (ctx.nomeLocal?.isNotEmpty ?? false)) estruturaGrupo.add(ctx.nomeLocal!);
    if (estruturaGrupo.isNotEmpty) linhas.add(estruturaGrupo.join(' | '));

    final elementoGrupo = <String>[];
    if (padrao.sistema && (ctx.nomeSistema?.isNotEmpty ?? false)) elementoGrupo.add(ctx.nomeSistema!);
    if (padrao.tipoElemento && (ctx.nomeTipoElemento?.isNotEmpty ?? false)) elementoGrupo.add(ctx.nomeTipoElemento!);
    if (padrao.elemento && (ctx.nomeElementoEspecifico?.isNotEmpty ?? false)) elementoGrupo.add(ctx.nomeElementoEspecifico!);
    if (elementoGrupo.isNotEmpty) linhas.add(elementoGrupo.join(' | '));

    if (padrao.latitudeLongitude && ctx.latitude != null && ctx.longitude != null) {
      linhas.add('Lat ${ctx.latitude!.toStringAsFixed(6)}, Long ${ctx.longitude!.toStringAsFixed(6)}');
    }

    if (padrao.descricao && (ctx.descricaoImagem?.isNotEmpty ?? false)) {
      linhas.add(ctx.descricaoImagem!);
    }

    final autoria = <String>[];
    if (padrao.nomeEmpresa && (ctx.nomeEmpresa?.isNotEmpty ?? false)) autoria.add(ctx.nomeEmpresa!);
    if (padrao.nomeUser && (ctx.nomeUsuario?.isNotEmpty ?? false)) autoria.add(ctx.nomeUsuario!);
    if (autoria.isNotEmpty) linhas.add(autoria.join(' | '));

    return linhas;
  }

  // Grava a legenda diretamente nos pixels da foto e retorna um novo arquivo JPEG temporário.
  // Se `padrao` não tiver nenhum campo habilitado ou nenhuma linha puder ser montada, retorna a foto original.
  static Future<File> aplicarLegenda({
    required File foto,
    required TimestampFotoPadraoModel padrao,
    required WatermarkFotoContexto contexto,
  }) async {
    final linhas = montarLinhas(padrao, contexto);
    final logoBytes = (padrao.logo && (contexto.logoUrl?.isNotEmpty ?? false))
        ? await _tentarBaixarLogo(contexto.logoUrl!)
        : null;
    debugPrint('[FotoWatermark] aplicarLegenda: ${linhas.length} linha(s) = $linhas, logo=${logoBytes != null}');
    if (linhas.isEmpty && logoBytes == null) {
      debugPrint('[FotoWatermark] nada para carimbar (nenhum campo resolveu texto e logo indisponível/desligado)');
      return foto;
    }

    final fotoBytes = await foto.readAsBytes();
    final composta = await _compor(
      fotoBytes: fotoBytes,
      linhas: linhas,
      padrao: padrao,
      logoBytes: logoBytes,
    );

    final tempDir = Directory.systemTemp;
    final destino = File(
      '${tempDir.path}/legenda_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await destino.writeAsBytes(composta);
    return destino;
  }

  // O mesmo logo servia a todas as fotos de um salvamento, mas era baixado de
  // novo a cada foto (20 fotos = 20 downloads, até 8s de timeout cada sem
  // sinal). Guarda só o último logo baixado: é sempre o da empresa do usuário.
  static String? _logoCacheUrl;
  static Uint8List? _logoCacheBytes;

  static Future<Uint8List?> _tentarBaixarLogo(String url) async {
    if (_logoCacheUrl == url && _logoCacheBytes != null) return _logoCacheBytes;
    try {
      final resposta = await StorageUrls.baixar(url).timeout(const Duration(seconds: 8));
      if (resposta.statusCode != 200) {
        debugPrint('[FotoWatermark] download do logo falhou: HTTP ${resposta.statusCode} ($url)');
        return null;
      }
      _logoCacheUrl = url;
      _logoCacheBytes = resposta.bodyBytes;
      return resposta.bodyBytes;
    } catch (e) {
      debugPrint('[FotoWatermark] erro ao baixar logo ($url): $e');
      return null;
    }
  }

  static Future<Uint8List> _compor({
    required Uint8List fotoBytes,
    required List<String> linhas,
    required TimestampFotoPadraoModel padrao,
    Uint8List? logoBytes,
  }) async {
    final codec = await ui.instantiateImageCodec(fotoBytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final ui.Image fotoOriginal = frame.image;
    final width = fotoOriginal.width.toDouble();
    final height = fotoOriginal.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
    canvas.drawImage(fotoOriginal, ui.Offset.zero, ui.Paint());

    final corTexto = corParaTexto(padrao.cor);
    final fontSize = width * (padrao.tamanho / 720.0);
    final clampedFontSize = fontSize.clamp(12.0, 64.0).toDouble();

    double blocoLargura = 0;
    double blocoAltura = 0;
    final paragraphs = <ui.Paragraph>[];

    for (final linha in linhas) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.left, fontSize: clampedFontSize, maxLines: 2, ellipsis: '…'),
      )
        ..pushStyle(ui.TextStyle(
          color: corTexto,
          fontSize: clampedFontSize,
          shadows: const [ui.Shadow(color: Colors.black87, blurRadius: 4, offset: ui.Offset(1, 1))],
        ))
        ..addText(linha);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: width * 0.9));
      paragraphs.add(paragraph);
      blocoLargura = paragraph.longestLine > blocoLargura ? paragraph.longestLine : blocoLargura;
      blocoAltura += paragraph.height;
    }

    const margem = 16.0;
    // Espaçamento entre o logo e o texto, um pouco maior nas legendas com fonte maior.
    final espacoLogo = 16.0 + clampedFontSize * 0.3;

    // Logo: entra dentro do mesmo bloco da legenda, ao lado do texto, seguindo
    // a posição escolhida para a legenda (não fica fixo em um canto).
    ui.Image? logoImage;
    double logoLado = 0;
    if (logoBytes != null) {
      final logoCodec = await ui.instantiateImageCodec(logoBytes);
      final logoFrame = await logoCodec.getNextFrame();
      logoCodec.dispose();
      logoImage = logoFrame.image;
      logoLado = clampedFontSize * 2.6;
    }

    final larguraTotal = blocoLargura + (logoImage != null ? logoLado + (blocoLargura > 0 ? espacoLogo : 0) : 0);
    final alturaTotal = logoImage != null && logoLado > blocoAltura ? logoLado : blocoAltura;

    double dx;
    double dy;
    final posicao = padrao.posicaoLegenda;
    if (posicao.contains('esquerdo')) {
      dx = margem;
    } else {
      dx = width - larguraTotal - margem;
    }
    if (posicao == 'Centro') {
      dx = (width - larguraTotal) / 2;
      dy = (height - alturaTotal) / 2;
    } else if (posicao.startsWith('Superior')) {
      dy = margem;
    } else {
      dy = height - alturaTotal - margem;
    }

    // Faixa semitransparente para garantir legibilidade sobre qualquer fundo.
    final faixaPaint = ui.Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(dx - 8, dy - 6, larguraTotal + 16, alturaTotal + 12),
        const ui.Radius.circular(6),
      ),
      faixaPaint,
    );

    double textoOffsetX = dx;
    if (logoImage != null) {
      final logoW = logoImage.width.toDouble();
      final logoH = logoImage.height.toDouble();
      final escala = (logoLado / logoW < logoLado / logoH) ? logoLado / logoW : logoLado / logoH;
      final destW = logoW * escala;
      final destH = logoH * escala;
      final destRect = ui.Rect.fromLTWH(
        dx + (logoLado - destW) / 2,
        dy + (alturaTotal - destH) / 2,
        destW,
        destH,
      );

      canvas.save();
      canvas.clipRRect(ui.RRect.fromRectAndRadius(destRect, ui.Radius.circular(logoLado * 0.12)));
      canvas.drawImageRect(logoImage, ui.Rect.fromLTWH(0, 0, logoW, logoH), destRect, ui.Paint());
      canvas.restore();

      textoOffsetX = dx + logoLado + espacoLogo;
    }

    double cursorY = dy + (alturaTotal - blocoAltura) / 2;
    for (final paragraph in paragraphs) {
      canvas.drawParagraph(paragraph, ui.Offset(textoOffsetX, cursorY));
      cursorY += paragraph.height;
    }

    final picture = recorder.endRecording();
    final imagemFinal = await picture.toImage(width.round(), height.round());
    // Libera os bitmaps nativos na hora: sem dispose eles só saem da memória
    // quando o GC do Dart roda, e num lote de 20 fotos isso acumulava vários
    // bitmaps por foto ao mesmo tempo.
    picture.dispose();
    fotoOriginal.dispose();
    logoImage?.dispose();
    for (final p in paragraphs) {
      p.dispose();
    }
    try {
      return await _paraJpg(imagemFinal, width.round(), height.round());
    } finally {
      imagemFinal.dispose();
    }
  }

  static Future<Uint8List> _paraJpg(ui.Image imagem, int width, int height) async {
    final byteData = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Falha ao renderizar a legenda sobre a foto.');
    }
    return FotoOtimizacaoService.codificarJpegRgba(byteData, width, height, qualidade: 85);
  }
}
