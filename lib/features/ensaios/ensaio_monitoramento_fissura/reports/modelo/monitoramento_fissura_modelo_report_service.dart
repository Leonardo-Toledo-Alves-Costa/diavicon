import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../../modelos_relatorios/repositories/modelos_relatorio_repository.dart';
import '../../../ensaios_inspecao_visual/reports/inspecao_visual_report_data.dart' show InspecaoVisualReportData;
import 'monitoramento_fissura_modelo_html_builder.dart';
import 'monitoramento_fissura_modelo_report_data.dart';

// Gera um relatório de Monitoramento de Fissuras a partir de um modelo
// (schema_json) e dos dados reais do ensaio — mesma estrutura de
// `ResistividadeModeloReportService` (fire-and-forget, roda desacoplado de
// qualquer tela). Este ensaio também não tem "inspeção geral": o relatório
// cobre todos os pontos de ensaio já cadastrados pra estrutura.
class MonitoramentoFissuraModeloReportService {
  final SupabaseClient _supabase;
  MonitoramentoFissuraModeloReportService(this._supabase);

  Future<void> gerar({
    required String relatorioId,
    required String modeloId,
    required String formato, // 'pdf' | 'html'
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
    required String nomeRelatorio,
  }) async {
    try {
      final modelo = await ModelosRelatorioRepository(_supabase).buscarPorId(modeloId);
      final schema = ModeloRelatorioSchema.fromJson(modelo.schemaJson);

      final dadosProjeto = InspecaoVisualReportData(_supabase);
      final dadosCabecalho = await dadosProjeto.buscarDadosCabecalho(projetoId, modelo.empresaId);
      final informacoesIniciais = await dadosProjeto.buscarInformacoesIniciais(projetoId, estruturaId);

      final dadosMf = MonitoramentoFissuraModeloReportData(_supabase);
      final pontos = await dadosMf.buscarPontosBrutos(projetoId: projetoId, estruturaId: estruturaId, tipoEnsaioId: tipoEnsaioId);
      final registros = await dadosMf.montarRegistros(pontos);

      final referencial = await dadosMf.buscarReferencial(
        catalogosNecessarios: schema.referencial.blocos.map((b) => b.catalogo).toList(),
        estruturaId: estruturaId,
        pontos: pontos,
        empresaId: modelo.empresaId,
      );

      List<Map<String, String>> linhasAgrupadas = const [];
      Map<String, String> graficosAgrupados = const {};
      if (schema.registrosAgrupados.ativo) {
        linhasAgrupadas = await dadosMf.buscarLinhasAgrupadas(pontos: pontos, hierarquia: schema.registrosAgrupados.hierarquia);
      }

      final html = MonitoramentoFissuraModeloHtmlBuilder.montar(
        schema: schema,
        nomeRelatorio: nomeRelatorio,
        dadosCabecalho: dadosCabecalho,
        informacoesIniciais: informacoesIniciais,
        referencial: referencial,
        registros: registros,
        linhasAgrupadas: linhasAgrupadas,
        graficosAgrupados: graficosAgrupados,
      );

      final String? tabelaGeralHtml = schema.resumo.ativo
          ? MonitoramentoFissuraModeloHtmlBuilder.montarTabelaGeral(schema: schema, nomeRelatorio: nomeRelatorio, registros: registros)
          : null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String urlArquivo;
      String? urlTabelaGeral;
      if (formato == 'pdf') {
        final dir = await getApplicationDocumentsDirectory();
        final arquivoPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
          content: await StorageUrls.assinarUrlsNoTexto(html),
          configuration: PrintPdfConfiguration(targetDirectory: dir.path, targetName: 'relatorio_$timestamp'),
        );
        final path = 'relatorios/monitoramento_fissura/$timestamp.pdf';
        await _supabase.storage.from('projetos').upload(path, arquivoPdf);
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);

        if (tabelaGeralHtml != null) {
          final arquivoTabelaPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
            content: await StorageUrls.assinarUrlsNoTexto(tabelaGeralHtml),
            configuration: PrintPdfConfiguration(
              targetDirectory: dir.path,
              targetName: 'relatorio_${timestamp}_tabela_geral',
              printOrientation: PrintOrientation.Landscape,
            ),
          );
          final pathTabela = 'relatorios/monitoramento_fissura/${timestamp}_tabela_geral.pdf';
          await _supabase.storage.from('projetos').upload(pathTabela, arquivoTabelaPdf);
          urlTabelaGeral = _supabase.storage.from('projetos').getPublicUrl(pathTabela);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final arquivoHtml = File('${tempDir.path}/relatorio_$timestamp.html');
        await arquivoHtml.writeAsBytes(Uint8List.fromList(utf8.encode(html)));
        final path = 'relatorios/monitoramento_fissura/$timestamp.html';
        await _supabase.storage
            .from('projetos')
            .upload(path, arquivoHtml, fileOptions: const FileOptions(contentType: 'text/html'));
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);

        if (tabelaGeralHtml != null) {
          final arquivoTabelaHtml = File('${tempDir.path}/relatorio_${timestamp}_tabela_geral.html');
          await arquivoTabelaHtml.writeAsBytes(Uint8List.fromList(utf8.encode(tabelaGeralHtml)));
          final pathTabela = 'relatorios/monitoramento_fissura/${timestamp}_tabela_geral.html';
          await _supabase.storage
              .from('projetos')
              .upload(pathTabela, arquivoTabelaHtml, fileOptions: const FileOptions(contentType: 'text/html'));
          urlTabelaGeral = _supabase.storage.from('projetos').getPublicUrl(pathTabela);
        }
      }

      await _supabase.from('relatorio_ensaio').update({
        'status': 'Concluído',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'url_arquivo': urlArquivo,
          if (urlTabelaGeral != null) 'url_resumo': urlTabelaGeral,
        }),
      }).eq('id', relatorioId);
    } catch (e) {
      await _supabase.from('relatorio_ensaio').update({
        'status': 'Erro',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'erro': e.toString(),
        }),
      }).eq('id', relatorioId);
    }
  }
}
