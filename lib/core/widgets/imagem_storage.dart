import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../services/storage_urls.dart';

/// Substituto direto de `NetworkImage` preparado para buckets privados.
///
/// Arquivos de bucket público (os atuais, ver [StorageUrls.bucketsPublicos])
/// abrem exatamente como antes: vira um `NetworkImage` com o endereço
/// original, com o mesmo cache e o mesmo carregamento nativo do Flutter
/// (inclusive no navegador). Só arquivos de bucket privado passam antes por
/// um link temporário.
@immutable
class StorageNetworkImage extends ImageProvider<NetworkImage> {
  const StorageNetworkImage(this.url, {this.scale = 1.0, this.headers});

  final String url;
  final double scale;
  final Map<String, String>? headers;

  @override
  Future<NetworkImage> obtainKey(ImageConfiguration configuration) {
    if (!StorageUrls.precisaAssinar(url)) {
      return SynchronousFuture<NetworkImage>(NetworkImage(url, scale: scale, headers: headers));
    }
    return StorageUrls.assinar(url).then((alvo) => NetworkImage(alvo, scale: scale, headers: headers));
  }

  @override
  ImageStreamCompleter loadImage(NetworkImage key, ImageDecoderCallback decode) {
    // ignore: invalid_use_of_protected_member
    return key.loadImage(key, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is StorageNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'StorageNetworkImage')}("$url", scale: ${scale.toStringAsFixed(1)})';
}

/// Substituto direto de `Image.network` (mesmos parâmetros) que usa
/// [StorageNetworkImage].
abstract final class ImagemStorage {
  static Widget network(
    String src, {
    Key? key,
    double scale = 1.0,
    ImageFrameBuilder? frameBuilder,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    String? semanticLabel,
    bool excludeFromSemantics = false,
    double? width,
    double? height,
    Color? color,
    Animation<double>? opacity,
    BlendMode? colorBlendMode,
    BoxFit? fit,
    AlignmentGeometry alignment = Alignment.center,
    ImageRepeat repeat = ImageRepeat.noRepeat,
    Rect? centerSlice,
    bool matchTextDirection = false,
    bool gaplessPlayback = false,
    FilterQuality filterQuality = FilterQuality.medium,
    bool isAntiAlias = false,
    Map<String, String>? headers,
    int? cacheWidth,
    int? cacheHeight,
  }) {
    // Bucket público: é literalmente o Image.network de antes.
    if (!StorageUrls.precisaAssinar(src)) {
      return Image.network(
        src,
        key: key,
        scale: scale,
        frameBuilder: frameBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
        width: width,
        height: height,
        color: color,
        opacity: opacity,
        colorBlendMode: colorBlendMode,
        fit: fit,
        alignment: alignment,
        repeat: repeat,
        centerSlice: centerSlice,
        matchTextDirection: matchTextDirection,
        gaplessPlayback: gaplessPlayback,
        filterQuality: filterQuality,
        isAntiAlias: isAntiAlias,
        headers: headers,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }
    return Image(
      key: key,
      image: ResizeImage.resizeIfNeeded(cacheWidth, cacheHeight, StorageNetworkImage(src, scale: scale, headers: headers)),
      frameBuilder: frameBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      width: width,
      height: height,
      color: color,
      opacity: opacity,
      colorBlendMode: colorBlendMode,
      fit: fit,
      alignment: alignment,
      repeat: repeat,
      centerSlice: centerSlice,
      matchTextDirection: matchTextDirection,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
    );
  }
}
