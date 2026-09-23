import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/modelo_rdo_schema.dart';
import 'rdo_modelo_html_builder.dart';
import 'rdo_modelo_report_data.dart';

/// Gera o relatório de RDO — mesmo desenho de `InspecaoVisualReportService`:
/// roda desacoplado da tela (fire-and-forget, sobrevive à navegação) e só faz
/// UPDATE na linha de status já criada por
/// `RelatorioRdoRepository.criarRelatorioPendente`, nunca insert.
class RdoModeloReportService {
  final SupabaseClient _supabase;
  RdoModeloReportService(this._supabase);

  Future<void> gerar({
    required String relatorioId,
    required String projetoId,
    required String empresaId,
    required String modeloId,
    required String nomeRelatorio,
    required String formato,
    required DateTime dataInicio,
    required DateTime dataFim,
    required String dataRotulo,
  }) async {
    try {
      final modeloRow = await _supabase.from('modelo_relatorio_rdo').select().eq('id', modeloId).single();
      final schema = ModeloRdoSchema.fromJson((modeloRow['schema_json'] as Map?)?.cast<String, dynamic>() ?? const {});

      final dados = RdoModeloReportData(_supabase);
      final dadosCabecalho = await dados.buscarDadosCabecalho(projetoId, empresaId);
      final informacoesIniciais = await dados.buscarInformacoesIniciais(projetoId);
      final registros = await dados.buscarRegistros(
        projetoId: projetoId,
        empresaId: empresaId,
        dataInicio: dataInicio,
        dataFim: dataFim,
      );

      final html = RdoModeloHtmlBuilder.montar(
        schema: schema,
        nomeRelatorio: nomeRelatorio,
        dadosCabecalho: dadosCabecalho,
        informacoesIniciais: informacoesIniciais,
        registros: registros,
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String urlArquivo;

      if (formato == 'html') {
        final arquivoHtml = File('${Directory.systemTemp.path}/relatorio_rdo_$timestamp.html')..writeAsStringSync(html);
        final path = 'relatorios/rdo/$timestamp.html';
        await _supabase.storage.from('projetos').upload(
              path,
              arquivoHtml,
              fileOptions: const FileOptions(contentType: 'text/html'),
            );
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final arquivoPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
          content: await StorageUrls.assinarUrlsNoTexto(html),
          configuration: PrintPdfConfiguration(targetDirectory: dir.path, targetName: 'relatorio_rdo_$timestamp'),
        );
        final path = 'relatorios/rdo/$timestamp.pdf';
        await _supabase.storage.from('projetos').upload(path, arquivoPdf);
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);
      }

      await _supabase.from('relatorio_rdo').update({
        'status': 'Concluído',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'data': dataRotulo,
          'url_arquivo': urlArquivo,
        }),
      }).eq('id', relatorioId);
    } catch (e) {
      await _supabase.from('relatorio_rdo').update({
        'status': 'Erro',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'data': dataRotulo,
          'erro': e.toString(),
        }),
      }).eq('id', relatorioId);
    }
  }
}
