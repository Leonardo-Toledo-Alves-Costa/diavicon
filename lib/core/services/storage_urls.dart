import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Endereço de um arquivo no Storage do Supabase.
class RefArquivoStorage {
  final String bucket;
  final String caminho;
  const RefArquivoStorage(this.bucket, this.caminho);

  String get chave => '$bucket/$caminho';
}

/// Links temporários para arquivos do Storage.
///
/// POR QUE: os buckets passaram a ser privados (LGPD). O banco continua
/// guardando o endereço "público" do arquivo
/// (`.../storage/v1/object/public/<bucket>/<caminho>`), mas ele agora serve
/// só como identificador: sem assinatura, o Supabase responde 400. Para
/// mostrar ou baixar, o app troca esse endereço por um link assinado, válido
/// por pouco tempo e gerado apenas para quem tem permissão de leitura (RLS
/// em storage.objects).
///
/// Guardar o endereço canônico (e não o link assinado) evita migrar as URLs
/// que já estão no banco e mantém tudo funcionando enquanto o bucket ainda
/// estiver público: se a assinatura falhar, devolve o endereço original.
abstract final class StorageUrls {
  static const Duration validadePadrao = Duration(hours: 1);

  /// Validade dos links dentro de HTML baixado para o aparelho: a pessoa pode
  /// abrir o arquivo de novo depois, então o link precisa durar mais.
  static const Duration validadeArquivoBaixado = Duration(days: 7);

  static final Map<String, ({String url, DateTime expira})> _cache = {};
  static final Map<String, Future<String>> _emAndamento = {};

  /// Buckets que continuam PÚBLICOS: os arquivos deles abrem pelo endereço
  /// público direto, sem link temporário (decisão de 21/09/2026: as fotos e
  /// documentos já existentes seguem acessíveis pelo link). A proteção deles
  /// é a das políticas do Storage: ninguém sem login lista, envia, altera ou
  /// apaga arquivos. Um bucket novo e privado (fora desta lista) passa
  /// automaticamente a usar links temporários.
  static const Set<String> bucketsPublicos = {
    'projetos',
    'estruturas',
    'avatars',
    'elementos-fotos',
    'relatorios',
    'empresas',
    'educacao_midias',
  };

  /// true quando o arquivo está num bucket privado e precisa de link
  /// temporário para abrir.
  static bool precisaAssinar(String? url) {
    final ref = referencia(url);
    return ref != null && !bucketsPublicos.contains(ref.bucket);
  }

  static const _marcador = '/storage/v1/object/';
  static const _tipos = {'public', 'sign', 'authenticated'};

  /// Extrai bucket e caminho de uma URL do Storage (pública, assinada ou
  /// autenticada). Devolve null para qualquer outra URL.
  static RefArquivoStorage? referencia(String? url) {
    if (url == null) return null;
    final texto = url.trim();
    final i = texto.indexOf(_marcador);
    if (i < 0) return null;
    var resto = texto.substring(i + _marcador.length);
    final corte = resto.indexOf(RegExp(r'[?#]'));
    if (corte >= 0) resto = resto.substring(0, corte);
    final partes = resto.split('/');
    if (partes.length < 3 || !_tipos.contains(partes[0]) || partes[1].isEmpty) return null;
    var caminho = partes.sublist(2).join('/');
    try {
      caminho = Uri.decodeComponent(caminho);
    } catch (_) {
      // Caminho com '%' solto: usa como está.
    }
    if (caminho.isEmpty) return null;
    return RefArquivoStorage(partes[1], caminho);
  }

  static bool ehDoStorage(String? url) => referencia(url) != null;

  /// Link assinado para [url]. URLs que não são do Storage voltam iguais.
  static Future<String> assinar(String url, {Duration validade = validadePadrao}) {
    final ref = referencia(url);
    if (ref == null || bucketsPublicos.contains(ref.bucket)) return Future.value(url);

    final chave = '${ref.chave}|${validade.inSeconds}';
    final emCache = _cache[chave];
    // Margem de 5 min para o link não vencer no meio do download.
    if (emCache != null && emCache.expira.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return Future.value(emCache.url);
    }
    return _emAndamento[chave] ??= _gerar(ref, url, validade, chave).whenComplete(() => _emAndamento.remove(chave));
  }

  static Future<String> _gerar(RefArquivoStorage ref, String original, Duration validade, String chave) async {
    try {
      final assinada = await Supabase.instance.client.storage
          .from(ref.bucket)
          .createSignedUrl(ref.caminho, validade.inSeconds);
      _cache[chave] = (url: assinada, expira: DateTime.now().add(validade));
      return assinada;
    } catch (e) {
      debugPrint('[StorageUrls] sem link assinado para ${ref.chave}: $e');
      return original;
    }
  }

  /// Baixa o arquivo (assinando antes quando for do Storage).
  static Future<http.Response> baixar(String url) async {
    final alvo = await assinar(url);
    return http.get(Uri.parse(alvo));
  }

  static final RegExp _urlsNoTexto = RegExp(
    r'''https?://[^\s"'<>(),;/]+/storage/v1/object/(?:public|sign|authenticated)/[^\s"'<>()?]+(?:\?token=[^\s"'<>()&]+)?''',
  );

  /// Troca, dentro de um texto (HTML de relatório), todo endereço do Storage
  /// por um link assinado. Usado antes de converter HTML em PDF e ao abrir um
  /// relatório HTML baixado.
  static Future<String> assinarUrlsNoTexto(String texto, {Duration validade = validadePadrao}) async {
    final encontradas = _urlsNoTexto.allMatches(texto).map((m) => m.group(0)!).toSet();
    if (encontradas.isEmpty) return texto;
    final trocas = <String, String>{};
    await Future.wait(encontradas.map((u) async {
      trocas[u] = await assinar(u, validade: validade);
    }));
    return texto.replaceAllMapped(_urlsNoTexto, (m) => trocas[m.group(0)!] ?? m.group(0)!);
  }

  /// Baixa um relatório HTML e devolve a resposta com as imagens internas já
  /// assinadas por [validadeArquivoBaixado]. Mantém o tipo `http.Response`
  /// para as telas continuarem usando `.bodyBytes`.
  static Future<http.Response> baixarHtml(String url) async {
    final resposta = await baixar(url);
    if (resposta.statusCode != 200) return resposta;
    String html;
    try {
      html = utf8.decode(resposta.bodyBytes);
    } catch (_) {
      return resposta;
    }
    final assinado = await assinarUrlsNoTexto(html, validade: validadeArquivoBaixado);
    return http.Response.bytes(utf8.encode(assinado), 200, headers: resposta.headers);
  }

  /// Esquece os links em cache (ex.: ao sair da conta).
  static void limparCache() {
    _cache.clear();
  }
}
