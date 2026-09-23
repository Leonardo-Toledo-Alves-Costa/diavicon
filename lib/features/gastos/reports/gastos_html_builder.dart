import '../models/gasto_model.dart';
import '../utils/agregacao_gastos.dart';

/// Gráficos já renderizados (data URI PNG) que entram no relatório.
class GraficosRelatorioGastos {
  /// Evolução no tempo. Vem primeiro no relatório: o período é escolhido por
  /// data, então é a pergunta que a escolha levanta.
  final String? porMes;
  final String? porProjeto;
  final String? porCategoria;
  final String? porUsuario;
  const GraficosRelatorioGastos({this.porMes, this.porProjeto, this.porCategoria, this.porUsuario});
}

/// HTML do relatório da Análise de Gastos (mesmo conteúdo da tela: totais,
/// gráficos e a tabela linha a linha). Puro — sem I/O —, para ser testável;
/// quem renderiza os gráficos e grava o arquivo é o GastosExportService.
class GastosHtmlBuilder {
  const GastosHtmlBuilder._();

  static String montar({
    required String empresaNome,
    required DateTime inicio,
    required DateTime fim,
    required List<GastoModel> gastos,
    GraficosRelatorioGastos graficos = const GraficosRelatorioGastos(),
    DateTime? geradoEm,
  }) {
    final totais = AgregacaoGastos.totais(gastos);
    final gerado = geradoEm ?? DateTime.now();
    final b = StringBuffer()
      ..write('<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">')
      ..write('<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..write('<title>Análise de Gastos — ${_e(empresaNome)}</title>')
      ..write('<style>$_css</style></head><body>')
      ..write('<header><h1>Análise de Gastos</h1>')
      ..write('<p class="sub">${_e(empresaNome)} · Período: ${formatarData(inicio)} a ${formatarData(fim)}</p>')
      ..write('<p class="sub">Gerado em ${formatarData(gerado)} · ${gastos.length} lançamento(s)</p></header>')
      ..write('<section class="cards">')
      ..write(_card('Total', totais.total))
      ..write(_card('Reembolsável', totais.reembolsavel, destaque: true))
      ..write(_card('Não reembolsável', totais.naoReembolsavel))
      ..write('</section>');

    void grafico(String titulo, String? dataUri) {
      if (dataUri == null) return;
      b.write('<section class="bloco"><h2>${_e(titulo)}</h2><img src="$dataUri" alt="${_e(titulo)}"></section>');
    }

    grafico('Gasto por mês', graficos.porMes);
    grafico('Gasto por projeto', graficos.porProjeto);
    grafico('Gasto por categoria', graficos.porCategoria);
    grafico('Gasto por usuário', graficos.porUsuario);

    b.write('<section class="bloco"><h2>Lançamentos</h2>');
    if (gastos.isEmpty) {
      b.write('<p class="vazio">Nenhum gasto no período.</p>');
    } else {
      b.write('<table><thead><tr>'
          '<th>Data</th><th>Usuário</th><th>Projeto</th><th>Categoria</th>'
          '<th class="num">Valor</th><th>Reembolsável</th><th>Meio</th>'
          '</tr></thead><tbody>');
      for (final g in gastos) {
        b.write('<tr>'
            '<td>${formatarData(g.data)}</td>'
            '<td>${_e(g.usuarioNome)}</td>'
            '<td>${_e(g.projetoNome)}</td>'
            '<td>${_e(g.categoriaNome)}</td>'
            '<td class="num">${formatarMoeda(g.valor)}</td>'
            '<td>${g.reembolsavel ? 'Sim' : 'Não'}</td>'
            '<td>${g.meioPagamento.rotulo}</td>'
            '</tr>');
      }
      b.write('<tr class="total"><td colspan="4">Total</td><td class="num">${formatarMoeda(totais.total)}</td><td colspan="2"></td></tr>');
      b.write('</tbody></table>');
    }
    b.write('</section></body></html>');
    return b.toString();
  }

  static String _card(String rotulo, double valor, {bool destaque = false}) =>
      '<div class="card${destaque ? ' destaque' : ''}"><span>${_e(rotulo)}</span><strong>${formatarMoeda(valor)}</strong></div>';

  static String _e(String texto) => texto
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static const _css = '''
body{font-family:Arial,Helvetica,sans-serif;color:#3E3E3D;margin:24px;font-size:12px}
header{border-bottom:3px solid #F9A232;padding-bottom:8px;margin-bottom:16px}
h1{font-size:22px;margin:0 0 4px}
h2{font-size:14px;margin:0 0 8px;color:#555}
.sub{margin:2px 0;color:#666}
.cards{display:flex;gap:10px;margin-bottom:18px}
.card{flex:1;background:#F7F6F3;border-radius:8px;padding:10px;text-align:center}
.card span{display:block;font-size:11px;color:#666}
.card strong{display:block;font-size:17px;margin-top:2px}
.card.destaque{background:#CDEBD6;color:#1E6B3F}
.card.destaque span{color:#1E6B3F}
.bloco{margin-bottom:18px;page-break-inside:avoid}
.bloco img{max-width:100%}
table{width:100%;border-collapse:collapse;font-size:10.5px}
th,td{border-bottom:1px solid #E4E1DA;padding:5px 4px;text-align:left;vertical-align:top}
th{background:#F7F6F3}
tr{page-break-inside:avoid}
.num{text-align:right;white-space:nowrap}
.total td{font-weight:bold;border-top:2px solid #3E3E3D}
.vazio{color:#888}
''';
}
