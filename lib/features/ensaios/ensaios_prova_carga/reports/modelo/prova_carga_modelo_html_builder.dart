import '../../../../modelos_relatorios/html/quadro_html_helpers.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../../modelos_relatorios/models/quadro_model.dart';
import '../../../ensaios_inspecao_visual/reports/inspecao_visual_report_data.dart' show InformacoesIniciaisReal;
import 'prova_carga_campos_catalogo.dart';
import 'prova_carga_modelo_report_data.dart';

// Monta o HTML do relatório de Prova de Carga Estática — mesma
// infraestrutura dos demais compositores, com duas diferenças: não tem
// "Registros agrupados" (pedido explícito do usuário — esse ensaio não
// suporta agrupamento) e a Tabela Geral usa linhas por PONTO DE MEDIÇÃO
// (já montadas em `ProvaCargaModeloReportData.montarLinhasTabelaGeral`),
// não por registro.
class ProvaCargaModeloHtmlBuilder {
  static String montar({
    required ModeloRelatorioSchema schema,
    required String nomeRelatorio,
    required Map<String, String> dadosCabecalho,
    required InformacoesIniciaisReal informacoesIniciais,
    required Map<String, List<Map<String, String>>> referencial,
    required List<RegistroProvaCargaReal> registros,
  }) {
    final d = schema.decoracao;
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    buffer.writeln('<style>${QuadroHtmlHelpers.css(d)}</style></head><body>');
    buffer.writeln('<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)}</h1>');

    if (schema.cabecalho.ativo) {
      buffer.writeln(QuadroHtmlHelpers.secao('Cabeçalho', d, () {
        return QuadroHtmlHelpers.montarQuadro(schema.cabecalho.quadro, dadosCabecalho, camposCabecalho, d, const [], const []);
      }));
    }

    if (schema.informacoesIniciais.ativo) {
      buffer.writeln(QuadroHtmlHelpers.secao('Informações iniciais', d, () {
        final blocoBuffer = StringBuffer();
        blocoBuffer.writeln(QuadroHtmlHelpers.blocoRepetido(
            'Informação da equipe', schema.informacoesIniciais.equipe, camposEquipe, d, informacoesIniciais.equipe));
        blocoBuffer.writeln(QuadroHtmlHelpers.blocoRepetido('Informação de empresas no projeto', schema.informacoesIniciais.empresas,
            camposEmpresasProjeto, d, informacoesIniciais.empresas));
        blocoBuffer.writeln(QuadroHtmlHelpers.blocoRepetido(
            'Estruturas no projeto', schema.informacoesIniciais.estruturas, camposEstruturasProjeto, d, informacoesIniciais.estruturas));
        blocoBuffer.writeln(
            QuadroHtmlHelpers.blocoRepetido('Locais da estrutura', schema.informacoesIniciais.locais, camposLocal, d, informacoesIniciais.locais));
        return blocoBuffer.toString();
      }));
    }

    if (schema.referencial.ativo && schema.referencial.blocos.isNotEmpty) {
      buffer.writeln(QuadroHtmlHelpers.secao('Referencial', d, () {
        final blocoBuffer = StringBuffer();
        for (final bloco in schema.referencial.blocos) {
          final catalogo = buscarCatalogoReferencial(bloco.catalogo);
          if (catalogo == null) continue;
          blocoBuffer.writeln(
              QuadroHtmlHelpers.blocoRepetido(catalogo.rotulo, bloco.quadro, catalogo.campos, d, referencial[bloco.catalogo] ?? const []));
        }
        return blocoBuffer.toString();
      }));
    }

    if (schema.registros.ativo) {
      final registrosHtml = StringBuffer();
      for (final registro in registros) {
        registrosHtml.writeln('<div class="cartao-registro">');
        registrosHtml.writeln(QuadroHtmlHelpers.montarQuadro(
          schema.registros.quadro,
          registro.dados,
          camposRegistroProvaCarga,
          d,
          const [],
          registro.fotos,
          subLista: registro.pontosMedicao,
          catalogoSubLista: camposPontoMedicaoProvaCarga,
        ));
        registrosHtml.writeln('</div>');
      }
      if (registros.isEmpty) registrosHtml.writeln('<p class="vazio">Nenhum ponto de ensaio encontrado.</p>');
      buffer.writeln(QuadroHtmlHelpers.secao('Registros', d, () => registrosHtml.toString()));
    }

    if (schema.galeria.ativo) {
      final fotos = registros.expand((r) => r.fotos).toList();
      buffer.writeln(QuadroHtmlHelpers.secao('Galeria', d, () => QuadroHtmlHelpers.galeria(fotos, schema.galeria), quebraPaginaAntes: true));
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  // Documento HTML separado, só com a Tabela geral, em paisagem — mesmo
  // motivo dos demais compositores. `linhas` já vem pronta (uma por ponto
  // de medição) de `ProvaCargaModeloReportData.montarLinhasTabelaGeral`.
  static String montarTabelaGeral({
    required ModeloRelatorioSchema schema,
    required String nomeRelatorio,
    required List<Map<String, String>> linhas,
  }) {
    final d = schema.decoracao;
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    buffer.writeln('<style>${QuadroHtmlHelpers.css(d)} @page { size: landscape; margin: 28px; }</style></head><body>');
    buffer.writeln('<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)} — Tabela geral</h1>');
    buffer.writeln(QuadroHtmlHelpers.secao('Tabela geral', d, () => QuadroHtmlHelpers.tabelaResumo(schema.resumo, linhas, d)));
    buffer.writeln('</body></html>');
    return buffer.toString();
  }
}
