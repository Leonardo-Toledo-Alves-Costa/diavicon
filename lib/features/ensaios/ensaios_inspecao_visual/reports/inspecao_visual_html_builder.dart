import '../../../modelos_relatorios/html/quadro_html_helpers.dart';
import '../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../modelos_relatorios/models/quadro_model.dart';
import 'inspecao_visual_report_data.dart';

// Monta o HTML do relatório de Inspeção Visual a partir do schema do modelo
// (Cabeçalho/Registros/Galeria/Resumo, cada um um Quadro Linha/Divisão/Slot)
// e dos dados reais já resolvidos (ver InspecaoVisualReportData). A
// montagem propriamente dita (CSS, tabelas, slots) é toda compartilhada via
// `QuadroHtmlHelpers` — este arquivo só orquestra a ORDEM das seções
// específica da Inspeção Visual.
class InspecaoVisualHtmlBuilder {
  static String montar({
    required ModeloRelatorioSchema schema,
    required String nomeRelatorio,
    required Map<String, String> dadosCabecalho,
    required InformacoesIniciaisReal informacoesIniciais,
    required ReferencialReal referencial,
    required List<RegistroReal> registros,
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
        // Locais fica depois de Estruturas e antes de Registros (dentro de
        // Informações iniciais, que já precede a seção de Registros).
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
              QuadroHtmlHelpers.blocoRepetido(catalogo.rotulo, bloco.quadro, catalogo.campos, d, referencial.paraCatalogo(bloco.catalogo)));
        }
        return blocoBuffer.toString();
      }));
    }

    if (schema.registros.ativo) {
      final registrosHtml = StringBuffer();
      for (final registro in registros) {
        registrosHtml.writeln('<div class="cartao-registro">');
        registrosHtml.writeln(
            QuadroHtmlHelpers.montarQuadro(schema.registros.quadro, registro.dados, camposRegistro, d, registro.anomalias, registro.fotos));
        registrosHtml.writeln('</div>');
      }
      if (registros.isEmpty) registrosHtml.writeln('<p class="vazio">Nenhum registro encontrado.</p>');
      buffer.writeln(QuadroHtmlHelpers.secao('Registros', d, () => registrosHtml.toString()));
    }

    if (schema.gutSomatorio.ativoPorEstrutura) {
      buffer.writeln(QuadroHtmlHelpers.secao(
          'GUT — Somatório por Estrutura', d, () => _tabelaGut('Estrutura', gutSomatorioPorEstrutura(registros), 'nome_estrutura_gut')));
    }

    if (schema.gutSomatorio.ativoPorLocal) {
      buffer.writeln(
          QuadroHtmlHelpers.secao('GUT — Somatório por Local', d, () => _tabelaGut('Local', gutSomatorioPorLocal(registros), 'nome_local_gut')));
    }

    if (schema.galeria.ativo) {
      final fotos = registros.expand((r) => r.fotos).toList();
      // Só a Galeria começa numa página nova — as demais seções correm
      // juntas, sem caixa separando uma da outra.
      buffer.writeln(QuadroHtmlHelpers.secao('Galeria', d, () => QuadroHtmlHelpers.galeria(fotos, schema.galeria), quebraPaginaAntes: true));
    }

    // A Tabela resumo NÃO entra aqui: ela vai numa página independente, em
    // paisagem (ver `montarResumo`) — um conversor de HTML->PDF só suporta
    // uma orientação por documento, então ela precisa ser um arquivo à parte.

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  // Documento HTML separado, só com a Tabela resumo, em orientação paisagem
  // — gerado (e, no caso de PDF, convertido) à parte do relatório principal,
  // já que `flutter_html_to_pdf_plus` só permite uma orientação por PDF.
  static String montarResumo({
    required ModeloRelatorioSchema schema,
    required String nomeRelatorio,
    required Map<String, String> dadosCabecalho,
    required Map<String, String> dadosEstrutura,
    required List<RegistroReal> registros,
  }) {
    final d = schema.decoracao;
    final linhas =
        agregarResumo(schema.resumo.colunas, registros, dadosCabecalho: dadosCabecalho, dadosEstrutura: dadosEstrutura);
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html><html><head><meta charset="utf-8">');
    buffer.writeln('<style>${QuadroHtmlHelpers.css(d)} @page { size: landscape; margin: 28px; }</style></head><body>');
    buffer.writeln('<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)} — Tabela resumo</h1>');
    buffer.writeln(QuadroHtmlHelpers.secao('Tabela resumo de registros', d, () => QuadroHtmlHelpers.tabelaResumo(schema.resumo, linhas, d)));
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  // Tabela fixa de 2 colunas (chave de agrupamento + soma de GUT) — mais
  // simples que `QuadroHtmlHelpers.tabelaResumo` (que depende de
  // `ResumoConfig`/colunas configuráveis), já que aqui as colunas nunca
  // variam. Reaproveita a mesma classe CSS `table.resumo`.
  static String _tabelaGut(String rotuloColuna, List<Map<String, String>> linhas, String campoChave) {
    final buffer = StringBuffer('<table class="resumo"><thead><tr><th>${QuadroHtmlHelpers.escapar(rotuloColuna)}</th><th>GUT (somatório)</th></tr></thead><tbody>');
    if (linhas.isEmpty) {
      buffer.write('<tr><td colspan="2" class="vazio">Nenhum dado.</td></tr>');
    }
    for (final linha in linhas) {
      buffer.write(
          '<tr><td>${QuadroHtmlHelpers.escapar(linha[campoChave] ?? '-')}</td><td>${QuadroHtmlHelpers.escapar(linha['gut_somatorio'] ?? '-')}</td></tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }
}
