import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Grava a cópia dos dados do titular e abre com o app do sistema.
/// Devolve o caminho do arquivo gravado.
Future<String> salvarExportacaoDados(String json, String nomeArquivo) async {
  final dir = await getApplicationDocumentsDirectory();
  final arquivo = File('${dir.path}/$nomeArquivo');
  await arquivo.writeAsString(json, encoding: utf8);
  await OpenFilex.open(arquivo.path, type: 'application/json');
  return arquivo.path;
}
