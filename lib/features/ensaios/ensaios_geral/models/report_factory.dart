import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';

import '../../ensaios_carbonatacao/reports/repositories/carbonatacao_report_service.dart';
// Importe outros serviços de relatório no futuro (Potencial, Esclerometria, etc.)


class RelatorioFactory {
  static Future<File> gerarEConverterRelatorio({
    required WidgetRef ref,
    required String tipoEnsaioNome,
    required String projetoId,
    required String estruturaId,
    required Map<String, dynamic> config,
  }) async {
    String htmlContent = '';
    final nomeLower = tipoEnsaioNome.toLowerCase();

    // Roteamento baseado no nome do ensaio
    if (nomeLower.contains('carbonata')) {
      final service = ref.read(carbonatacaoReportServiceProvider);
      htmlContent = await service.gerarHtml(
        projetoId: projetoId, 
        estruturaId: estruturaId, 
        config: config
      );
    } else {
      throw UnimplementedError('Geração de relatório não implementada para: $tipoEnsaioNome');
    }

    // Busca o diretório temporário do dispositivo para salvar o PDF
    final dir = await getApplicationDocumentsDirectory();
    final String nomeArquivoLimpo = config['nome_relatorio'].toString().replaceAll('-', '_').replaceAll('-', '/');

    // 👇 Conversão de HTML para PDF local usando o pacote Plus
    final arquivoPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
      content: await StorageUrls.assinarUrlsNoTexto(htmlContent),
      configuration: PrintPdfConfiguration( 
      targetDirectory: dir.path, 
      targetName: nomeArquivoLimpo,
      ),
    );

    return arquivoPdf;
  }
}