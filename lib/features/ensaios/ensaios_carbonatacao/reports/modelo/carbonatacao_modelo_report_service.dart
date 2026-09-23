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
import 'carbonatacao_modelo_html_builder.dart';
import 'carbonatacao_modelo_report_data.dart';

// Gera um relatório de Carbonatação a partir de um modelo (schema_json) e
// dos dados reais do ensaio, e atualiza a linha `relatorio_ensaio`
// correspondente — mesma estrutura de `InspecaoVisualReportService` (roda
// desacoplado de qualquer tela, fire-and-forget). Diferente da Inspeção
// Visual, Carbonatação não tem o conceito de "inspeção geral" — o relatório
// cobre todos os pontos de ensaio da estrutura no projeto.
//
// Cabeçalho/Informações iniciais são resolvidos reaproveitando
// `InspecaoVisualReportData` (são conceitos de Projeto/Empresa/Estrutura/
// Local, agnósticos de ensaio, apesar do nome do arquivo — candidato a virar
// um resolvedor compartilhado em `modelos_relatorios/` numa próxima limpeza).
class CarbonatacaoModeloReportService {
  final SupabaseClient _supabase;
  CarbonatacaoModeloReportService(this._supabase);

  Future<void> gerar({
    required String relatorioId,
    required String modeloId,
    required String formato, // 'pdf' | 'html'
    required String projetoId,
    required String estruturaId,
    required String nomeRelatorio,
  }) async {
    try {
      final modelo = await ModelosRelatorioRepository(_supabase).buscarPorId(modeloId);
      final schema = ModeloRelatorioSchema.fromJson(modelo.schemaJson);

      final dadosProjeto = InspecaoVisualReportData(_supabase);
      final dadosCabecalho = await dadosProjeto.buscarDadosCabecalho(projetoId, modelo.empresaId);
      final informacoesIniciais = await dadosProjeto.buscarInformacoesIniciais(projetoId, estruturaId);

      final dadosCarb = CarbonatacaoModeloReportData(_supabase);
      final idade = await dadosCarb.buscarIdadeEstrutura(estruturaId);
      final pontos = await dadosCarb.buscarPontosBrutos(projetoId: projetoId, estruturaId: estruturaId);
      final registros = await dadosCarb.montarRegistros(pontos, idade);

      final referencial = await dadosCarb.buscarReferencial(
        catalogosNecessarios: schema.referencial.blocos.map((b) => b.catalogo).toList(),
        estruturaId: estruturaId,
        pontos: pontos,
        empresaId: modelo.empresaId,
      );

      List<Map<String, String>> linhasAgrupadas = const [];
      Map<String, String> graficosAgrupados = const {};
      if (schema.registrosAgrupados.ativo) {
        linhasAgrupadas =
            await dadosCarb.buscarLinhasAgrupadas(pontos: pontos, hierarquia: schema.registrosAgrupados.hierarquia, idade: idade);
        graficosAgrupados = await dadosCarb.gerarGraficosAgrupados(
          graficosSelecionados: _camposUsados(schema.registrosAgrupados.graficos),
          pontos: pontos,
          idade: idade,
        );
      }

      final html = CarbonatacaoModeloHtmlBuilder.montar(
        schema: schema,
        nomeRelatorio: nomeRelatorio,
        dadosCabecalho: dadosCabecalho,
        informacoesIniciais: informacoesIniciais,
        referencial: referencial,
        registros: registros,
        linhasAgrupadas: linhasAgrupadas,
        graficosAgrupados: graficosAgrupados,
      );

      // A Tabela geral é gerada como um arquivo à parte, em paisagem —
      // mesmo motivo do relatório de Inspeção Visual (ver
      // `InspecaoVisualHtmlBuilder.montarResumo`).
      final String? tabelaGeralHtml = schema.resumo.ativo
          ? CarbonatacaoModeloHtmlBuilder.montarTabelaGeral(schema: schema, nomeRelatorio: nomeRelatorio, registros: registros)
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
        final path = 'relatorios/carbonatacao/$timestamp.pdf';
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
          final pathTabela = 'relatorios/carbonatacao/${timestamp}_tabela_geral.pdf';
          await _supabase.storage.from('projetos').upload(pathTabela, arquivoTabelaPdf);
          urlTabelaGeral = _supabase.storage.from('projetos').getPublicUrl(pathTabela);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final arquivoHtml = File('${tempDir.path}/relatorio_$timestamp.html');
        await arquivoHtml.writeAsBytes(Uint8List.fromList(utf8.encode(html)));
        final path = 'relatorios/carbonatacao/$timestamp.html';
        await _supabase.storage
            .from('projetos')
            .upload(path, arquivoHtml, fileOptions: const FileOptions(contentType: 'text/html'));
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);

        if (tabelaGeralHtml != null) {
          final arquivoTabelaHtml = File('${tempDir.path}/relatorio_${timestamp}_tabela_geral.html');
          await arquivoTabelaHtml.writeAsBytes(Uint8List.fromList(utf8.encode(tabelaGeralHtml)));
          final pathTabela = 'relatorios/carbonatacao/${timestamp}_tabela_geral.html';
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

  // O usuário monta o Quadro de "Registros agrupados" livremente (linha por
  // linha, igual a qualquer outra seção) — aqui só extraímos QUAIS gráficos
  // foram efetivamente colocados em algum slot, pra gerar só esses.
  Set<String> _camposUsados(Quadro quadro) {
    final chaves = <String>{};
    for (final linha in quadro.linhas) {
      for (final divisao in linha.divisoes) {
        final campo = divisao.conteudo?.campoVinculado;
        if (campo != null) chaves.add(campo);
      }
    }
    return chaves;
  }
}
