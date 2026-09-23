import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../../modelos_relatorios/models/quadro_model.dart';
import '../../../../modelos_relatorios/repositories/modelos_relatorio_repository.dart';
import '../../../ensaios_inspecao_visual/reports/inspecao_visual_report_data.dart' show InspecaoVisualReportData;
import 'lp_modelo_html_builder.dart';
import 'lp_modelo_report_data.dart';

// Gera o relatório de Líquido penetrante a partir de um modelo (schema_json)
// — fire-and-forget, mesmo fluxo de `ChumbadorModeloReportService`: cobre
// todos os elementos ensaiados da estrutura.
class LPModeloReportService {
  final SupabaseClient _supabase;
  LPModeloReportService(this._supabase);

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

      final dados = LPModeloReportData(_supabase);
      final elementos = await dados.buscarElementos(projetoId: projetoId, estruturaId: estruturaId, tipoEnsaioId: tipoEnsaioId);
      final registros = dados.montarRegistros(elementos);
      final referencial = await dados.buscarReferencial(
        catalogosNecessarios: schema.referencial.blocos.map((b) => b.catalogo).toList(),
        estruturaId: estruturaId,
      );

      var linhasAgrupadas = const <Map<String, String>>[];
      var graficosAgrupados = const <String, String>{};
      if (schema.registrosAgrupados.ativo) {
        linhasAgrupadas = dados.linhasAgrupadas(elementos: elementos, hierarquia: schema.registrosAgrupados.hierarquia);
        graficosAgrupados = await dados.graficosAgrupados(selecionados: _camposUsados(schema.registrosAgrupados.graficos), elementos: elementos);
      }

      final html = LPModeloHtmlBuilder.montar(
        schema: schema,
        nomeRelatorio: nomeRelatorio,
        dadosCabecalho: dadosCabecalho,
        informacoesIniciais: informacoesIniciais,
        referencial: referencial,
        registros: registros,
        linhasAgrupadas: linhasAgrupadas,
        graficosAgrupados: graficosAgrupados,
      );
      final tabelaGeralHtml =
          schema.resumo.ativo ? LPModeloHtmlBuilder.montarTabelaGeral(schema: schema, nomeRelatorio: nomeRelatorio, registros: registros) : null;

      final ts = DateTime.now().millisecondsSinceEpoch;
      final storage = _supabase.storage.from('projetos');
      final String urlArquivo;
      String? urlTabelaGeral;

      if (formato == 'pdf') {
        final dir = await getApplicationDocumentsDirectory();
        final pdf = await FlutterHtmlToPdf.convertFromHtmlContent(
          content: await StorageUrls.assinarUrlsNoTexto(html),
          configuration: PrintPdfConfiguration(targetDirectory: dir.path, targetName: 'relatorio_lp_$ts'),
        );
        final path = 'relatorios/liquido_penetrante/$ts.pdf';
        await storage.upload(path, pdf);
        urlArquivo = storage.getPublicUrl(path);
        if (tabelaGeralHtml != null) {
          final pdfTabela = await FlutterHtmlToPdf.convertFromHtmlContent(
            content: await StorageUrls.assinarUrlsNoTexto(tabelaGeralHtml),
            configuration: PrintPdfConfiguration(
              targetDirectory: dir.path,
              targetName: 'relatorio_lp_${ts}_tabela_geral',
              printOrientation: PrintOrientation.Landscape,
            ),
          );
          final pathTabela = 'relatorios/liquido_penetrante/${ts}_tabela_geral.pdf';
          await storage.upload(pathTabela, pdfTabela);
          urlTabelaGeral = storage.getPublicUrl(pathTabela);
        }
      } else {
        Future<String> subirHtml(String conteudo, String nome) async {
          final arquivo = File('${Directory.systemTemp.path}/$nome.html');
          await arquivo.writeAsBytes(Uint8List.fromList(utf8.encode(conteudo)));
          final path = 'relatorios/liquido_penetrante/$nome.html';
          await storage.upload(path, arquivo, fileOptions: const FileOptions(contentType: 'text/html'));
          return storage.getPublicUrl(path);
        }

        urlArquivo = await subirHtml(html, '$ts');
        if (tabelaGeralHtml != null) urlTabelaGeral = await subirHtml(tabelaGeralHtml, '${ts}_tabela_geral');
      }

      await _supabase.from('relatorio_ensaio').update({
        'status': 'Concluído',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'url_arquivo': urlArquivo,
          'url_resumo': ?urlTabelaGeral,
        }),
      }).eq('id', relatorioId);
    } catch (e) {
      await _supabase.from('relatorio_ensaio').update({
        'status': 'Erro',
        'conteudo': jsonEncode({'nome_relatorio': nomeRelatorio, 'modelo_id': modeloId, 'formato': formato, 'erro': e.toString()}),
      }).eq('id', relatorioId);
    }
  }

  Set<String> _camposUsados(Quadro quadro) => {
        for (final linha in quadro.linhas)
          for (final divisao in linha.divisoes)
            if (divisao.conteudo?.campoVinculado != null) divisao.conteudo!.campoVinculado!,
      };
}
