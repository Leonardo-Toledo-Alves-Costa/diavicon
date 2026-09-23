import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../modelos_relatorios/repositories/modelos_relatorio_repository.dart';
import 'inspecao_visual_html_builder.dart';
import 'inspecao_visual_report_data.dart';

// Gera um relatório de Inspeção Visual a partir de um modelo (schema_json) e
// dos dados reais da inspeção, e atualiza a linha `relatorio_ensaio`
// correspondente com o resultado (ou o erro). Roda desacoplado de qualquer
// tela — pode continuar rodando mesmo se o usuário navegar pra outro lugar,
// já que só depende do SupabaseClient, não de BuildContext/WidgetRef.
class InspecaoVisualReportService {
  final SupabaseClient _supabase;
  InspecaoVisualReportService(this._supabase);

  Future<void> gerar({
    required String relatorioId,
    required String modeloId,
    required String formato, // 'pdf' | 'html'
    required String projetoId,
    required String estruturaId,
    required String inspecaoGeralId,
    required String nomeRelatorio,
  }) async {
    try {
      final modelo = await ModelosRelatorioRepository(_supabase).buscarPorId(modeloId);
      final schema = ModeloRelatorioSchema.fromJson(modelo.schemaJson);

      final dadosResolver = InspecaoVisualReportData(_supabase);
      final dadosCabecalho = await dadosResolver.buscarDadosCabecalho(projetoId, modelo.empresaId);
      final informacoesIniciais = await dadosResolver.buscarInformacoesIniciais(projetoId, estruturaId);
      final registros = await dadosResolver.buscarRegistros(inspecaoGeralId: inspecaoGeralId, estruturaId: estruturaId);
      final referencial = await dadosResolver.buscarReferencial(
        catalogosNecessarios: schema.referencial.blocos.map((b) => b.catalogo).toList(),
        estruturaId: estruturaId,
        inspecaoGeralId: inspecaoGeralId,
        locais: informacoesIniciais.locais,
        empresaId: modelo.empresaId,
      );

      final html = InspecaoVisualHtmlBuilder.montar(
        schema: schema,
        nomeRelatorio: nomeRelatorio,
        dadosCabecalho: dadosCabecalho,
        informacoesIniciais: informacoesIniciais,
        referencial: referencial,
        registros: registros,
      );

      // A Tabela resumo é gerada como um arquivo à parte, em paisagem — ver
      // o comentário em `InspecaoVisualHtmlBuilder.montarResumo`.
      final String? resumoHtml = schema.resumo.ativo
          ? InspecaoVisualHtmlBuilder.montarResumo(
              schema: schema,
              nomeRelatorio: nomeRelatorio,
              dadosCabecalho: dadosCabecalho,
              dadosEstrutura: informacoesIniciais.estruturas.isNotEmpty ? informacoesIniciais.estruturas.first : const {},
              registros: registros,
            )
          : null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String urlArquivo;
      String? urlResumo;
      if (formato == 'pdf') {
        final dir = await getApplicationDocumentsDirectory();
        final arquivoPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
          content: await StorageUrls.assinarUrlsNoTexto(html),
          configuration: PrintPdfConfiguration(targetDirectory: dir.path, targetName: 'relatorio_$timestamp'),
        );
        final path = 'relatorios/inspecao_visual/$timestamp.pdf';
        await _supabase.storage.from('projetos').upload(path, arquivoPdf);
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);

        if (resumoHtml != null) {
          final arquivoResumoPdf = await FlutterHtmlToPdf.convertFromHtmlContent(
            content: await StorageUrls.assinarUrlsNoTexto(resumoHtml),
            configuration: PrintPdfConfiguration(
              targetDirectory: dir.path,
              targetName: 'relatorio_${timestamp}_resumo',
              printOrientation: PrintOrientation.Landscape,
            ),
          );
          final pathResumo = 'relatorios/inspecao_visual/${timestamp}_resumo.pdf';
          await _supabase.storage.from('projetos').upload(pathResumo, arquivoResumoPdf);
          urlResumo = _supabase.storage.from('projetos').getPublicUrl(pathResumo);
        }
      } else {
        final tempDir = Directory.systemTemp;
        final arquivoHtml = File('${tempDir.path}/relatorio_$timestamp.html');
        await arquivoHtml.writeAsBytes(Uint8List.fromList(utf8.encode(html)));
        final path = 'relatorios/inspecao_visual/$timestamp.html';
        await _supabase.storage
            .from('projetos')
            .upload(path, arquivoHtml, fileOptions: const FileOptions(contentType: 'text/html'));
        urlArquivo = _supabase.storage.from('projetos').getPublicUrl(path);

        if (resumoHtml != null) {
          final arquivoResumoHtml = File('${tempDir.path}/relatorio_${timestamp}_resumo.html');
          await arquivoResumoHtml.writeAsBytes(Uint8List.fromList(utf8.encode(resumoHtml)));
          final pathResumo = 'relatorios/inspecao_visual/${timestamp}_resumo.html';
          await _supabase.storage
              .from('projetos')
              .upload(pathResumo, arquivoResumoHtml, fileOptions: const FileOptions(contentType: 'text/html'));
          urlResumo = _supabase.storage.from('projetos').getPublicUrl(pathResumo);
        }
      }

      await _supabase.from('relatorio_ensaio').update({
        'status': 'Concluído',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'inspecao_geral_id': inspecaoGeralId,
          'url_arquivo': urlArquivo,
          if (urlResumo != null) 'url_resumo': urlResumo,
        }),
      }).eq('id', relatorioId);
    } catch (e) {
      await _supabase.from('relatorio_ensaio').update({
        'status': 'Erro',
        'conteudo': jsonEncode({
          'nome_relatorio': nomeRelatorio,
          'modelo_id': modeloId,
          'formato': formato,
          'inspecao_geral_id': inspecaoGeralId,
          'erro': e.toString(),
        }),
      }).eq('id', relatorioId);
    }
  }
}
