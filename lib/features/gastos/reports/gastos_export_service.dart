import 'package:diavicon/core/services/storage_urls.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_html_to_pdf_plus/flutter_html_to_pdf_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../models/gasto_model.dart';
import '../utils/agregacao_gastos.dart';
import '../utils/gastos_csv.dart';
import 'gastos_html_builder.dart';

enum FormatoExportacaoGastos {
  csv('CSV (planilha)'),
  html('HTML'),
  pdf('PDF');

  final String rotulo;
  const FormatoExportacaoGastos(this.rotulo);
}

/// Exporta a Análise de Gastos exatamente com os filtros da tela. Tudo é
/// gerado no aparelho (é só o flatten de uma consulta) e aberto no app
/// padrão do sistema — de onde o usuário compartilha.
class GastosExportService {
  const GastosExportService._();

  static const _corReembolsavel = Color(0xFF2E9E62);
  static const _corNaoReembolsavel = Color(0xFF8A94A6);
  // Mais que isso vira um gráfico ilegível; o resto soma em "Outros".
  static const _maxBarras = 12;

  static Future<File> exportar({
    required FormatoExportacaoGastos formato,
    required String empresaNome,
    required DateTime inicio,
    required DateTime fim,
    required List<GastoModel> gastos,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final nomeBase = 'gastos_${GastoModel.dataIso(inicio)}_a_${GastoModel.dataIso(fim)}';

    final File arquivo;
    switch (formato) {
      case FormatoExportacaoGastos.csv:
        arquivo = File('${dir.path}/$nomeBase.csv');
        await arquivo.writeAsString(GastosCsv.gerar(gastos), encoding: utf8);
      case FormatoExportacaoGastos.html:
        final html = await _html(empresaNome, inicio, fim, gastos);
        arquivo = File('${dir.path}/$nomeBase.html');
        await arquivo.writeAsString(html, encoding: utf8);
      case FormatoExportacaoGastos.pdf:
        final html = await _html(empresaNome, inicio, fim, gastos);
        arquivo = await FlutterHtmlToPdf.convertFromHtmlContent(
          content: await StorageUrls.assinarUrlsNoTexto(html),
          configuration: PrintPdfConfiguration(targetDirectory: dir.path, targetName: nomeBase),
        );
    }

    // Tipo explícito: sem ele o Android adivinha pela extensão e, quando erra,
    // o aplicativo escolhido abre o arquivo como se fosse outra coisa — e
    // costuma anunciar isso como "arquivo corrompido".
    final resultado = await OpenFilex.open(arquivo.path, type: _tipoMime(formato));
    if (resultado.type != ResultType.done) {
      throw Exception('Arquivo gerado em ${arquivo.path}, mas não há app para abri-lo (${resultado.message}).');
    }
    return arquivo;
  }

  static Future<String> _html(String empresaNome, DateTime inicio, DateTime fim, List<GastoModel> gastos) async {
    Future<String?> grafico(List<ItemAgregado> itens) async {
      if (itens.isEmpty) return null;
      return RelatorioChartRenderer.barrasSegmentadas(
        tituloEixoY: 'R\$',
        grupos: [
          for (final i in _limitar(itens))
            BarraSegmentadaGrupo(rotulo: i.rotulo, segmentos: [
              SegmentoBarra(rotulo: 'Reembolsável', valor: i.reembolsavel, cor: _corReembolsavel),
              SegmentoBarra(rotulo: 'Não reembolsável', valor: i.naoReembolsavel, cor: _corNaoReembolsavel),
            ]),
        ],
      );
    }

    // Mês a mês, com o mesmo desenho dos outros: cada barra dividida entre
    // o que é reembolsável e o que não é.
    final mensais = [
      for (final m in AgregacaoGastos.porMesNoPeriodo(gastos, inicio, fim))
        ItemAgregado(
          chave: '${m.mes.year}-${m.mes.month}',
          rotulo: rotuloMesAnoCurto(m.mes),
          valor: m.valor,
          reembolsavel: gastos
              .where((g) => AgregacaoGastos.mesmoMes(g.data, m.mes) && g.reembolsavel)
              .fold(0.0, (soma, g) => soma + g.valor),
          naoReembolsavel: gastos
              .where((g) => AgregacaoGastos.mesmoMes(g.data, m.mes) && !g.reembolsavel)
              .fold(0.0, (soma, g) => soma + g.valor),
        ),
    ];

    return GastosHtmlBuilder.montar(
      empresaNome: empresaNome,
      inicio: inicio,
      fim: fim,
      gastos: gastos,
      graficos: GraficosRelatorioGastos(
        // Meses vão na ordem do calendário, sem passar pelo corte de
        // "Outros" — um relatório de 12 meses tem 12 barras e pronto.
        porMes: mensais.isEmpty
            ? null
            : await RelatorioChartRenderer.barrasSegmentadas(
                tituloEixoY: 'R\$',
                grupos: [
                  for (final m in mensais)
                    BarraSegmentadaGrupo(rotulo: m.rotulo, segmentos: [
                      SegmentoBarra(rotulo: 'Reembolsável', valor: m.reembolsavel, cor: _corReembolsavel),
                      SegmentoBarra(rotulo: 'Não reembolsável', valor: m.naoReembolsavel, cor: _corNaoReembolsavel),
                    ]),
                ],
              ),
        porProjeto: await grafico(AgregacaoGastos.porProjeto(gastos)),
        porCategoria: await grafico(AgregacaoGastos.porCategoria(gastos)),
        porUsuario: await grafico(AgregacaoGastos.porUsuario(gastos)),
      ),
    );
  }

  /// Tipo do arquivo, para o sistema escolher o aplicativo certo.
  static String _tipoMime(FormatoExportacaoGastos formato) => switch (formato) {
        FormatoExportacaoGastos.csv => 'text/csv',
        FormatoExportacaoGastos.html => 'text/html',
        // No navegador o "PDF" sai como HTML para imprimir.
        FormatoExportacaoGastos.pdf => kIsWeb ? 'text/html' : 'application/pdf',
      };

  static List<ItemAgregado> _limitar(List<ItemAgregado> itens) {
    if (itens.length <= _maxBarras) return itens;
    final resto = itens.skip(_maxBarras - 1);
    return [
      ...itens.take(_maxBarras - 1),
      ItemAgregado(
        chave: '_outros',
        rotulo: 'Outros',
        valor: resto.fold(0.0, (s, i) => s + i.valor),
        reembolsavel: resto.fold(0.0, (s, i) => s + i.reembolsavel),
        naoReembolsavel: resto.fold(0.0, (s, i) => s + i.naoReembolsavel),
      ),
    ];
  }
}
