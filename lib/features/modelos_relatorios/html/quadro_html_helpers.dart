import '../models/foto_relatorio.dart';
import '../models/modelo_relatorio_schema.dart';
import '../models/paleta_cores.dart';
import '../models/quadro_model.dart';
import '../../../core/security/entrada_segura.dart';

// Renderização HTML compartilhada de um Quadro (Linha/Divisão/Slot), usada
// por qualquer gerador de relatório (Inspeção Visual, Carbonatação...) — a
// única parte ensaio-específica é a resolução dos dados em si
// (InspecaoVisualReportData/CarbonatacaoModeloReportData); a montagem do
// HTML/CSS é sempre a mesma. Extraído de `InspecaoVisualHtmlBuilder` quando
// o compositor de Carbonatação foi adicionado, pra não duplicar ~150 linhas
// de CSS/tabela por ensaio.
//
// Layout em <table> (não flex/grid): o conversor de HTML->PDF usado
// (flutter_html_to_pdf_plus) tem suporte limitado/inconsistente a CSS3
// flexbox/grid — tabelas são o jeito mais confiável de garantir colunas
// lado a lado tanto no HTML quanto no PDF gerado.
class QuadroHtmlHelpers {
  static String css(DecoracaoGlobalConfig d) => '''
    @page { margin: 28px; }
    body { font-family: Arial, Helvetica, sans-serif; color: #333; margin: 0; padding: 20px; }
    .titulo-relatorio { font-size: 22px; margin: 0 0 10px 0; }
    .secao { margin-bottom: 8px; }
    .secao-quebra-pagina { page-break-before: always; }
    .secao-titulo { font-size: ${d.tamanhoFonteTitulo}px; font-weight: bold; color: #666; letter-spacing: 0.3px; text-transform: uppercase; margin-bottom: 4px; }
    .bloco-repeticao { margin-bottom: 6px; }
    .bloco-titulo { font-weight: bold; color: #666; margin-bottom: 2px; }
    table.linha-tabela { width: 100%; border-collapse: collapse; table-layout: fixed; margin-bottom: 1px; }
    table.linha-tabela td { padding: 2px 4px; vertical-align: top; font-size: ${d.tamanhoFonteValor}px; }
    .campo-titulo { font-weight: bold; color: #666; font-size: ${d.tamanhoFonteRotulo}px; }
    .cartao-registro { background: #fff; border: 1px solid #e0e0e0; border-radius: 8px; padding: 8px; margin-bottom: 6px; page-break-inside: avoid; }
    .anomalia { margin: 4px 0 0 0; padding: 6px; background: #f5f8ff; border: 1px solid #dde6fb; border-radius: 6px; }
    table.galeria-tabela { width: 100%; border-collapse: collapse; table-layout: fixed; }
    table.galeria-tabela td { padding: 5px; vertical-align: top; text-align: center; font-size: 11px; color: #777; }
    table.galeria-tabela img { border-radius: 6px; }
    table.resumo { border-collapse: collapse; width: 100%; }
    table.resumo th, table.resumo td { border: 1px solid #ddd; padding: 6px 10px; font-size: ${d.tamanhoFonteValor}px; text-align: left; }
    table.resumo th { background: #f0f0f0; font-size: ${d.tamanhoFonteRotulo}px; }
    .vazio { color: #999; font-size: 12px; }
  ''';

  // Todas as seções correm juntas (sem caixa separando uma da outra) — só
  // quem chama com `quebraPaginaAntes: true` (ex: Galeria) começa página nova.
  static String secao(String titulo, DecoracaoGlobalConfig decoracao, String Function() conteudo, {bool quebraPaginaAntes = false}) {
    final tituloHtml = decoracao.mostrarTitulos
        ? '<div class="secao-titulo" style="text-align:${cssAlign(decoracao.alinhamentoTitulo)}">${escapar(titulo)}</div>'
        : '';
    final classe = quebraPaginaAntes ? 'secao secao-quebra-pagina' : 'secao';
    return '<div class="$classe">$tituloHtml${conteudo()}</div>';
  }

  static String cssAlign(AlinhamentoTitulo a) {
    switch (a) {
      case AlinhamentoTitulo.esquerda:
        return 'left';
      case AlinhamentoTitulo.centro:
        return 'center';
      case AlinhamentoTitulo.direita:
        return 'right';
      case AlinhamentoTitulo.justificado:
        return 'justify';
    }
  }

  static String corCss(String chave) {
    // toARGB32() é o jeito já usado no resto do app pra extrair componentes
    // de Color (ver marcacao_planta_popup.dart) — evita depender da escala
    // (0-1 vs 0-255) das getters .r/.g/.b da API nova de Color.
    final argb = corDaPaleta(chave).toARGB32();
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return 'rgb($r,$g,$b)';
  }

  static String bordaCss(DecoracaoGlobalConfig decoracao) {
    if (!decoracao.bordaAtiva) return '';
    return 'border:${decoracao.bordaEspessura.largura}px solid ${corCss(decoracao.bordaCor)};';
  }

  // Um bloco nomeado de repetição (equipe/empresas/estruturas/pontos de
  // ensaio...): repete o Quadro uma vez por linha real resolvida.
  static String blocoRepetido(
    String titulo,
    Quadro quadro,
    List<CampoCatalogo> catalogo,
    DecoracaoGlobalConfig decoracao,
    List<Map<String, String>> linhas,
  ) {
    if (linhas.isEmpty) return '';
    final buffer = StringBuffer(
        '<div class="bloco-repeticao"><div class="bloco-titulo" style="font-size:${decoracao.tamanhoFonteRotulo}px;">${escapar(titulo)}</div>');
    for (final dados in linhas) {
      buffer.writeln('<div class="cartao-registro">${montarQuadro(quadro, dados, catalogo, decoracao, const [], const [])}</div>');
    }
    buffer.writeln('</div>');
    return buffer.toString();
  }

  // Monta um Quadro inteiro (todas as linhas/divisões/slots). `subLista`/
  // `catalogoSubLista` só são necessários quando o Quadro tem algum slot do
  // tipo `TipoConteudoSlot.subLista` (mesmo mecanismo de `anomalias`,
  // generalizado — ex: "Pontos de leitura" da Resistividade).
  static String montarQuadro(
    Quadro quadro,
    Map<String, String> dados,
    List<CampoCatalogo> catalogo,
    DecoracaoGlobalConfig decoracao,
    List<Map<String, String>> anomalias,
    List<FotoRelatorio> fotosRegistro, {
    List<Map<String, String>> subLista = const [],
    List<CampoCatalogo> catalogoSubLista = const [],
  }) {
    final buffer = StringBuffer();
    for (final linha in quadro.linhas) {
      if (linha.ehBloco) {
        final conteudo = linha.divisoes.first.conteudo!;
        if (conteudo.tipo == TipoConteudoSlot.anomalias) {
          final quadroAninhado = conteudo.quadroAninhado;
          if (quadroAninhado != null) {
            for (final anomalia in anomalias) {
              buffer.writeln(
                  '<div class="anomalia">${montarQuadro(quadroAninhado, anomalia, camposAnomalia, decoracao, const [], const [])}</div>');
            }
          }
          continue;
        }
        if (conteudo.tipo == TipoConteudoSlot.subLista) {
          final quadroAninhado = conteudo.quadroAninhado;
          if (quadroAninhado != null) {
            for (final item in subLista) {
              buffer.writeln(
                  '<div class="anomalia">${montarQuadro(quadroAninhado, item, catalogoSubLista, decoracao, const [], const [])}</div>');
            }
          }
          continue;
        }
        if (conteudo.tipo == TipoConteudoSlot.galeria) {
          // Fotos do próprio registro (não as de outros registros).
          buffer.writeln(galeriaComAltura(fotosRegistro, conteudo.colunas, conteudo.mostrarDescricao, conteudo.alturaImagem, conteudo.ajusteImagem));
          continue;
        }
        if (conteudo.tipo == TipoConteudoSlot.matriz) {
          // Valor já vem pré-montado como HTML de tabela (não é texto a escapar).
          final html = dados[conteudo.campoVinculado];
          if (html != null && html.isNotEmpty) buffer.writeln(html);
          continue;
        }
        continue;
      }

      buffer.write('<table class="linha-tabela"><tr>');
      for (final divisao in linha.divisoes) {
        buffer.write('<td style="width:${divisao.larguraPercentual.round().clamp(1, 100)}%;">');
        buffer.write(slot(divisao.conteudo, dados, catalogo, decoracao));
        buffer.write('</td>');
      }
      buffer.write('</tr></table>');
    }
    return buffer.toString();
  }

  static String slot(ConteudoSlot? conteudo, Map<String, String> dados, List<CampoCatalogo> catalogo, DecoracaoGlobalConfig decoracao) {
    if (conteudo == null) return '';

    switch (conteudo.tipo) {
      case TipoConteudoSlot.imagem:
        final url = EntradaSegura.urlHtml(dados[conteudo.campoVinculado]);
        if (url.isEmpty) return '';
        return '<img src="$url" style="width:100%;height:${conteudo.alturaImagem.round()}px;object-fit:${conteudo.ajusteImagem.cssObjectFit};border-radius:6px;" />';
      case TipoConteudoSlot.galeria:
      case TipoConteudoSlot.anomalias:
      case TipoConteudoSlot.subLista:
      case TipoConteudoSlot.matriz:
        return '';
      case TipoConteudoSlot.texto:
        break;
    }

    final valor = valorParaHtml(dados[conteudo.campoVinculado] ?? '');
    final rotulo = buscarCampo(catalogo, conteudo.campoVinculado)?.rotulo ?? '';

    RegraCondicional? regraAplicada;
    for (final regra in conteudo.decoracaoCondicional) {
      final valorReferencia = dados[regra.campoReferencia] ?? '';
      if (regra.operador.avalia(valorReferencia, regra.valorComparacao)) {
        regraAplicada = regra;
        break;
      }
    }

    String miolo;
    if (!decoracao.mostrarTituloCampos || rotulo.isEmpty) {
      miolo = '<span style="font-size:${decoracao.tamanhoFonteValor}px;">$valor</span>';
    } else if (decoracao.posicaoTituloCampo == PosicaoTituloCampo.acima) {
      miolo = '<div class="campo-titulo">${escapar(rotulo)}:</div><div style="font-size:${decoracao.tamanhoFonteValor}px;">$valor</div>';
    } else {
      miolo = '<span class="campo-titulo">${escapar(rotulo)}: </span><span style="font-size:${decoracao.tamanhoFonteValor}px;">$valor</span>';
    }

    // Padding sempre presente na célula (não só quando uma regra bate) —
    // sem isso o conteúdo fica colado na borda.
    if (regraAplicada == null) {
      return '<div style="${bordaCss(decoracao)}padding:2px 6px;border-radius:4px;">$miolo</div>';
    }

    final corTexto = corCss(regraAplicada.corTexto);
    final corFundo = corCss(regraAplicada.corFundo);
    return '<div style="${bordaCss(decoracao)}color:$corTexto;background:$corFundo;padding:2px 6px;border-radius:4px;font-weight:600;">$miolo</div>';
  }

  static String galeria(List<FotoRelatorio> fotos, GaleriaConfig config) =>
      galeriaComAltura(fotos, config.colunas, config.mostrarDescricao, config.alturaImagem, config.ajusteImagem);

  static String galeriaComAltura(
    List<FotoRelatorio> fotos,
    int colunas,
    bool mostrarDescricao,
    double alturaImagem,
    AjusteImagem ajuste,
  ) {
    if (fotos.isEmpty) return '<p class="vazio">Nenhuma foto.</p>';
    final larguraColuna = (100 / colunas).floor();
    final buffer = StringBuffer('<table class="galeria-tabela"><tbody>');
    for (var i = 0; i < fotos.length; i += colunas) {
      buffer.write('<tr>');
      for (var c = 0; c < colunas; c++) {
        final idx = i + c;
        if (idx >= fotos.length) {
          buffer.write('<td></td>');
          continue;
        }
        final foto = fotos[idx];
        buffer.write('<td style="width:$larguraColuna%;">');
        buffer.write(
            '<img src="${EntradaSegura.urlHtml(foto.url)}" style="width:100%;height:${alturaImagem.round()}px;object-fit:${ajuste.cssObjectFit};" />');
        if (mostrarDescricao && foto.descricao.isNotEmpty) {
          buffer.write('<div>${escapar(foto.descricao)}</div>');
        }
        buffer.write('</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  static String tabelaResumo(ResumoConfig config, List<Map<String, String>> linhas, DecoracaoGlobalConfig decoracao) {
    final buffer = StringBuffer('<table class="resumo"><thead><tr>');
    for (final c in config.colunas) {
      buffer.write('<th>${escapar(c.rotulo)}</th>');
    }
    buffer.write('</tr></thead><tbody>');
    if (linhas.isEmpty) {
      buffer.write('<tr><td colspan="${config.colunas.length}" class="vazio">Nenhum dado.</td></tr>');
    }
    for (final linha in linhas) {
      buffer.write('<tr>');
      for (final c in config.colunas) {
        final valor = c.ehCalculada ? calcularColunaResumo(c, linha) : (linha[c.campoVinculado ?? 'quantidade'] ?? '-');
        buffer.write('<td>${escapar(valor)}</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  /// Resolve uma "coluna calculada" (fórmula + regras condicionais, ver
  /// `ResumoColuna` em modelo_relatorio_schema.dart) pra UMA linha da tabela
  /// resumo. Os operandos chegam aqui já formatados pra exibição (ex:
  /// "92,4 kN") — nunca como `double` — porque cada `*_modelo_report_data.dart`
  /// monta o mapa `dados`/`linha` assim pra tudo mais na tabela; então é
  /// preciso extrair o número de volta antes de operar.
  static String calcularColunaResumo(ResumoColuna coluna, Map<String, String> linha) {
    if (coluna.operandos.length < 2 || coluna.operadores.length != coluna.operandos.length - 1) return '-';
    final primeiro = _valorOperando(coluna, coluna.operandos.first, linha);
    if (primeiro == null) return '-';
    var acumulado = primeiro;
    for (var i = 0; i < coluna.operadores.length; i++) {
      final valor = _valorOperando(coluna, coluna.operandos[i + 1], linha);
      if (valor == null) return '-';
      acumulado = coluna.operadores[i].aplicar(acumulado, valor);
    }
    for (final regra in coluna.regras) {
      if (regra.operador.avalia(acumulado.toString(), regra.valorComparacao.toString())) {
        return regra.textoResultado;
      }
    }
    if (coluna.textoPadrao != null && coluna.textoPadrao!.trim().isNotEmpty) return coluna.textoPadrao!;
    return acumulado.toStringAsFixed(coluna.casasDecimais);
  }

  /// Valor numérico de um operando da fórmula: se o campo tiver uma
  /// `NumeralizacaoCampo` (variável categórica, ex: CAA), resolve o valor
  /// bruto da linha pela tabela de mapeamento; senão extrai o número direto
  /// do texto formatado.
  static double? _valorOperando(ResumoColuna coluna, String chave, Map<String, String> linha) {
    for (final n in coluna.numeralizacoes) {
      if (n.campo == chave) return n.resolver(linha[chave]);
    }
    return _extrairNumero(linha[chave]);
  }

  /// Extrai um número de um texto já formatado pra exibição — remove
  /// unidade/espaços e resolve a vírgula decimal brasileira ("92,4 kN" -> 92.4,
  /// "1.234,56" -> 1234.56, "92.4" já em ponto -> 92.4).
  static double? _extrairNumero(String? texto) {
    if (texto == null) return null;
    var limpo = texto.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (limpo.isEmpty) return null;
    if (limpo.contains(',')) {
      limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(limpo);
  }

  /// Escapa texto para conteúdo e atributos (inclui aspas — sem isso um
  /// valor com `"` saía de dentro de um `href="…"`).
  static String escapar(String texto) => EntradaSegura.html(texto);

  // Campos de texto cujo valor é um link (ex: "Mapa (link)") viram um <a>
  // clicável no HTML em vez de texto plano.
  static String valorParaHtml(String valor) {
    final link = EntradaSegura.urlHtml(valor, permitirDataImagem: false);
    if (link.isNotEmpty) {
      return '<a href="$link" target="_blank" rel="noopener noreferrer">Ver no mapa</a>';
    }
    return escapar(valor);
  }
}
