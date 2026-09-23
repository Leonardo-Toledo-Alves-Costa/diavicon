import '../../../../modelos_relatorios/html/quadro_html_helpers.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../../../modelos_relatorios/models/quadro_model.dart';
import '../../../ensaios_inspecao_visual/reports/inspecao_visual_report_data.dart' show InformacoesIniciaisReal;
import 'lp_campos_catalogo.dart';
import 'lp_modelo_report_data.dart';

// HTML do relatório de Líquido penetrante — mesma infraestrutura e ordem dos
// demais compositores (ver `chumbador_modelo_html_builder.dart`): Registros
// repete por elemento, com a sub-lista "Pontos de LP" dentro.
class LPModeloHtmlBuilder {
  static String montar({
    required ModeloRelatorioSchema schema,
    required String nomeRelatorio,
    required Map<String, String> dadosCabecalho,
    required InformacoesIniciaisReal informacoesIniciais,
    required Map<String, List<Map<String, String>>> referencial,
    required List<RegistroLPReal> registros,
    required List<Map<String, String>> linhasAgrupadas,
    required Map<String, String> graficosAgrupados,
  }) {
    final d = schema.decoracao;
    final b = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln('<style>${QuadroHtmlHelpers.css(d)}</style></head><body>')
      ..writeln('<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)}</h1>');

    if (schema.cabecalho.ativo) {
      b.writeln(QuadroHtmlHelpers.secao(
          'Cabeçalho', d, () => QuadroHtmlHelpers.montarQuadro(schema.cabecalho.quadro, dadosCabecalho, camposCabecalho, d, const [], const [])));
    }

    if (schema.informacoesIniciais.ativo) {
      b.writeln(QuadroHtmlHelpers.secao('Informações iniciais', d, () {
        final ii = schema.informacoesIniciais;
        return [
          QuadroHtmlHelpers.blocoRepetido('Informação da equipe', ii.equipe, camposEquipe, d, informacoesIniciais.equipe),
          QuadroHtmlHelpers.blocoRepetido('Informação de empresas no projeto', ii.empresas, camposEmpresasProjeto, d, informacoesIniciais.empresas),
          QuadroHtmlHelpers.blocoRepetido('Estruturas no projeto', ii.estruturas, camposEstruturasProjeto, d, informacoesIniciais.estruturas),
          QuadroHtmlHelpers.blocoRepetido('Locais da estrutura', ii.locais, camposLocal, d, informacoesIniciais.locais),
        ].join('\n');
      }));
    }

    if (schema.referencial.ativo && schema.referencial.blocos.isNotEmpty) {
      b.writeln(QuadroHtmlHelpers.secao('Referencial', d, () {
        final blocos = StringBuffer();
        for (final bloco in schema.referencial.blocos) {
          final catalogo = buscarCatalogoReferencial(bloco.catalogo);
          if (catalogo == null) continue;
          blocos.writeln(QuadroHtmlHelpers.blocoRepetido(catalogo.rotulo, bloco.quadro, catalogo.campos, d, referencial[bloco.catalogo] ?? const []));
        }
        return blocos.toString();
      }));
    }

    if (schema.registros.ativo) {
      final html = StringBuffer();
      for (final r in registros) {
        html
          ..writeln('<div class="cartao-registro">')
          ..writeln(QuadroHtmlHelpers.montarQuadro(
            schema.registros.quadro,
            r.dados,
            camposRegistroLP,
            d,
            const [],
            r.fotos,
            subLista: r.pontos,
            catalogoSubLista: camposPontoLP,
          ))
          ..writeln('</div>');
      }
      if (registros.isEmpty) html.writeln('<p class="vazio">Nenhum elemento ensaiado.</p>');
      b.writeln(QuadroHtmlHelpers.secao('Registros', d, () => html.toString()));
    }

    if (schema.registrosAgrupados.ativo) {
      b.writeln(QuadroHtmlHelpers.secao('Registros agrupados', d, () {
        return '${_tabelaAgrupada(schema.registrosAgrupados, linhasAgrupadas)}\n'
            '${QuadroHtmlHelpers.montarQuadro(schema.registrosAgrupados.graficos, graficosAgrupados, camposGraficosAgrupadosLP, d, const [], const [])}';
      }));
    }

    if (schema.galeria.ativo) {
      final fotos = registros.expand((r) => r.fotos).toList();
      b.writeln(QuadroHtmlHelpers.secao('Galeria', d, () => QuadroHtmlHelpers.galeria(fotos, schema.galeria), quebraPaginaAntes: true));
    }

    b.writeln('</body></html>');
    return b.toString();
  }

  // Tabela geral em documento separado, paisagem (mesmo padrão dos demais).
  static String montarTabelaGeral({required ModeloRelatorioSchema schema, required String nomeRelatorio, required List<RegistroLPReal> registros}) {
    final d = schema.decoracao;
    return '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<style>${QuadroHtmlHelpers.css(d)} @page { size: landscape; margin: 28px; }</style></head><body>'
        '<h1 class="titulo-relatorio">${QuadroHtmlHelpers.escapar(nomeRelatorio)} — Tabela geral</h1>'
        '${QuadroHtmlHelpers.secao('Tabela geral', d, () => QuadroHtmlHelpers.tabelaResumo(schema.resumo, registros.map((r) => r.dados).toList(), d))}'
        '</body></html>';
  }

  static String _tabelaAgrupada(RegistrosAgrupadosConfig config, List<Map<String, String>> linhas) {
    if (config.colunas.isEmpty) return '';
    final b = StringBuffer('<table class="resumo"><thead><tr>');
    for (final c in config.colunas) {
      b.write('<th>${QuadroHtmlHelpers.escapar(c.rotulo)}</th>');
    }
    b.write('</tr></thead><tbody>');
    if (linhas.isEmpty) b.write('<tr><td colspan="${config.colunas.length}" class="vazio">Nenhum dado.</td></tr>');
    for (final linha in linhas) {
      b.write('<tr>');
      for (final c in config.colunas) {
        b.write('<td>${QuadroHtmlHelpers.escapar(linha[c.campoVinculado] ?? '-')}</td>');
      }
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }
}
