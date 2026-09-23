import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/esclerometria_model.dart' show DirecaoImpacto;

// Busca e calcula os dados reais de Esclerometria pro compositor de
// relatório. Fórmulas replicadas de `analise_esclerometria_screen.dart`
// (única fonte): uma leitura é "aceita"/válida quando seu desvio em relação
// à média de TODAS as leituras do PONTO é <= 10%. Importante: a coluna
// `status` de `ponto_ensaio_esclerometria_leituras` NÃO é usada — a própria
// tela de análise por ponto já ignora esse valor salvo e recalcula a
// condição na hora (ver `_aceita`), então o relatório replica esse
// recálculo pra ficar consistente com o que o app mostra ao vivo.
class RegistroEsclerometriaReal {
  final Map<String, String> dados;
  final List<FotoRelatorio> fotos;
  const RegistroEsclerometriaReal({required this.dados, required this.fotos});
}

class LeituraEsclerometriaBruta {
  final int valorQ;
  const LeituraEsclerometriaBruta({required this.valorQ});
}

class PontoEsclerometriaBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final String? fotoJanela;
  final String? fotoEnsaio;
  final int inclinacao;
  final int indiceK;
  final String correcaoInclinacao;
  final List<LeituraEsclerometriaBruta> leituras;
  final List<FotoRelatorio> fotos;

  const PontoEsclerometriaBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.fotoJanela,
    required this.fotoEnsaio,
    required this.inclinacao,
    required this.indiceK,
    required this.correcaoInclinacao,
    required this.leituras,
    required this.fotos,
  });
}

class EsclerometriaModeloReportData {
  final SupabaseClient _supabase;
  EsclerometriaModeloReportData(this._supabase);

  static const Color _corAprovada = Color(0xFFF9A232); // amarelo Diavicon (AppColors.primary)
  static const Color _corReprovada = Color(0xFFBDBDBD); // cinza — mesma cor usada em analise_esclerometria_screen.dart

  Future<List<PontoEsclerometriaBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_esclerometria(inclinacao, indice_k, correcao_inclinacao, foto_janela, foto_ensaio,
            ponto_ensaio_esclerometria_leituras(valor_Q)),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoEsclerometriaBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final escBruto = p['ponto_ensaio_esclerometria'];
      final esc = escBruto is List && escBruto.isNotEmpty
          ? (escBruto.first as Map<String, dynamic>)
          : (escBruto is Map ? escBruto.cast<String, dynamic>() : null);
      if (esc == null) continue; // ponto sem dados de esclerometria preenchidos ainda

      final leiturasResp = esc['ponto_ensaio_esclerometria_leituras'] as List? ?? const [];
      final leituras = leiturasResp.map((l) => LeituraEsclerometriaBruta(valorQ: (l['valor_Q'] as num?)?.toInt() ?? 0)).toList();

      final fotos = <FotoRelatorio>[];
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoEsclerometriaBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        fotoJanela: esc['foto_janela']?.toString(),
        fotoEnsaio: esc['foto_ensaio']?.toString(),
        inclinacao: (esc['inclinacao'] as num?)?.toInt() ?? 0,
        indiceK: (esc['indice_k'] as num?)?.toInt() ?? 1,
        correcaoInclinacao: esc['correcao_inclinacao']?.toString() ?? '',
        leituras: leituras,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  double _media(List<int> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  // Leituras aceitas (desvio <= 10% da média de TODAS as leituras do ponto).
  List<double> _aceitas(List<int> v) {
    final media = _media(v);
    if (media == 0) return const [];
    return v.where((x) => ((x - media) / media).abs() <= 0.10).map((x) => x.toDouble()).toList();
  }

  double _mediaLista(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  double _cvLista(List<double> v) {
    if (v.length < 2) return 0;
    final media = _mediaLista(v);
    if (media == 0) return 0;
    final somaQuad = v.fold<double>(0, (a, x) => a + (x - media) * (x - media));
    final desvio = sqrt(somaQuad / v.length);
    return desvio / media * 100;
  }

  // Barra por leitura (aprovada/reprovada) + linha da média geral (todas as
  // leituras, igual ao PlotBand da tela ao vivo) — igual à aba "Gráficos" de
  // `analise_esclerometria_screen.dart`.
  Future<String> _graficoBarrasLeituras(PontoEsclerometriaBruto p) async {
    if (p.leituras.isEmpty) return '';
    final qs = p.leituras.map((l) => l.valorQ).toList();
    final media = _media(qs);

    final grupos = <BarraGrupo>[];
    for (var i = 0; i < p.leituras.length; i++) {
      final valorQ = p.leituras[i].valorQ;
      final aceita = media != 0 && ((valorQ - media) / media).abs() <= 0.10;
      grupos.add(BarraGrupo(rotulo: 'L${i + 1}', valor: valorQ.toDouble(), cor: aceita ? _corAprovada : _corReprovada));
    }

    return RelatorioChartRenderer.barrasComMediaHorizontal(
      grupos: grupos,
      media: media,
      tituloEixoY: 'Índice esclerométrico (Q)',
      corPadrao: _corReprovada,
    );
  }

  // Boxplot com TODAS as leituras do ponto (não só as aceitas) — mesmo dado
  // usado na aba "Estatísticas" de `analise_esclerometria_screen.dart`.
  Future<String> _boxplotDistribuicao(PontoEsclerometriaBruto p) async {
    if (p.leituras.isEmpty) return '';
    final qs = p.leituras.map((l) => l.valorQ).toList();
    final valores = qs.map((v) => v.toDouble()).toList();
    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(nome: 'Índice esclerométrico (Q)', cor: _corAprovada, grupos: [
          GrupoBoxplot(rotulo: p.nomePonto, minimo: valores.reduce(min), media: _media(qs), maximo: valores.reduce(max)),
        ]),
      ],
      tituloEixoY: 'Índice esclerométrico (Q)',
    );
  }

  // Tabela HTML: Leitura / Valor (Q) / Desvio % / Condição — mesma fórmula
  // de desvio (`_delta`) e mesmo limiar de aceite (10%) da aba "Tabelas" de
  // `analise_esclerometria_screen.dart`.
  String _tabelaLeiturasHtml(PontoEsclerometriaBruto p) {
    if (p.leituras.isEmpty) return '';
    final qs = p.leituras.map((l) => l.valorQ).toList();
    final media = _media(qs);

    final buffer = StringBuffer('<table class="resumo"><thead><tr><th>Leitura</th><th>Valor (Q)</th><th>Desvio %</th><th>Condição</th></tr></thead><tbody>');
    for (var i = 0; i < p.leituras.length; i++) {
      final valorQ = p.leituras[i].valorQ;
      final delta = media == 0 ? 0.0 : (valorQ - media) / media;
      final aceita = delta.abs() <= 0.10;
      final deltaTexto = '${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%';
      final corCondicao = aceita ? '#2E7D32' : '#C62828';
      buffer.write(
          '<tr><td>L${i + 1}</td><td>$valorQ</td><td>$deltaTexto</td><td style="color:$corCondicao;font-weight:bold;">${aceita ? 'Aceita' : 'Rejeitada'}</td></tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  Future<RegistroEsclerometriaReal> _montarRegistroIndividual(PontoEsclerometriaBruto p) async {
    final qs = p.leituras.map((l) => l.valorQ).toList();
    final aceitas = _aceitas(qs);
    final media = _mediaLista(aceitas);
    final cv = _cvLista(aceitas);
    final grafico = await _graficoBarrasLeituras(p);
    final boxplot = await _boxplotDistribuicao(p);
    final tabela = _tabelaLeiturasHtml(p);

    return RegistroEsclerometriaReal(
      dados: {
        'nome_elemento_esc': p.nomeElemento,
        'tipo_elemento_esc': p.tipoElemento,
        'local_elemento_esc': p.local,
        'revestimento_elemento_esc': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_esc': p.marcacaoImagemUrl!,
        'nome_ponto_esc': p.nomePonto,
        'valor_resultado_esc': p.valorResultado,
        if (p.fotoJanela != null && p.fotoJanela!.isNotEmpty) 'imagem_marcacao_area_esc': p.fotoJanela!,
        if (p.fotoEnsaio != null && p.fotoEnsaio!.isNotEmpty) 'imagem_realizacao_ensaio_esc': p.fotoEnsaio!,
        'inclinacao_esc': '${p.inclinacao}°',
        'direcao_impacto_esc': DirecaoImpacto.fromGraus(p.inclinacao).label,
        'indice_k_esc': '${p.indiceK}',
        'correcao_inclinacao_esc': p.correcaoInclinacao,
        'media_valor_q_esc': media.toStringAsFixed(1),
        'leituras_validas_esc': '${aceitas.length}',
        'cv_esc': '${cv.toStringAsFixed(1)}%',
        if (grafico.isNotEmpty) 'grafico_barras_leituras_esc': grafico,
        if (tabela.isNotEmpty) 'tabela_leituras_esc': tabela,
        if (boxplot.isNotEmpty) 'boxplot_distribuicao_esc': boxplot,
      },
      fotos: p.fotos,
    );
  }

  Future<List<RegistroEsclerometriaReal>> montarRegistros(List<PontoEsclerometriaBruto> pontos) async {
    final registros = <RegistroEsclerometriaReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoEsclerometriaBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoEsclerometriaBruto>>{};
    final rotulos = <String, ({String local, String tipo})>{};
    for (final p in pontos) {
      final String chave;
      switch (hierarquia) {
        case HierarquiaAgrupamento.local:
          chave = p.local;
          break;
        case HierarquiaAgrupamento.tipoElemento:
          chave = p.tipoElemento;
          break;
        case HierarquiaAgrupamento.localTipoElemento:
          chave = '${p.local}|${p.tipoElemento}';
          break;
      }
      grupos.putIfAbsent(chave, () => []).add(p);
      rotulos[chave] = (local: p.local, tipo: p.tipoElemento);
    }

    final linhas = <Map<String, String>>[];
    for (final entrada in grupos.entries) {
      // Pool das leituras JÁ ACEITAS de cada ponto (a aceitação é decidida
      // por ponto, com a média daquele ponto — não recalculada de novo com
      // uma média do grupo inteiro).
      final aceitasPool = <double>[];
      var totalAprovadas = 0;
      for (final p in entrada.value) {
        final aceitas = _aceitas(p.leituras.map((l) => l.valorQ).toList());
        totalAprovadas += aceitas.length;
        aceitasPool.addAll(aceitas);
      }
      final indicesK = entrada.value.map((p) => '${p.indiceK}').toSet().join(', ');
      final correcoes = entrada.value.map((p) => p.correcaoInclinacao).where((v) => v.isNotEmpty).toSet().join(', ');
      final direcoes = entrada.value.map((p) => DirecaoImpacto.fromGraus(p.inclinacao).label).toSet().join(', ');

      linhas.add({
        'local_grupo_esc': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_esc': rotulos[entrada.key]!.tipo,
        'indice_k_grupo_esc': indicesK,
        'correcao_inclinacao_grupo_esc': correcoes,
        'direcao_impacto_grupo_esc': direcoes,
        'media_valor_q_grupo_esc': aceitasPool.isEmpty ? '-' : _mediaLista(aceitasPool).toStringAsFixed(1),
        'leituras_aprovadas_grupo_esc': '$totalAprovadas',
        'cv_grupo_esc': '${_cvLista(aceitasPool).toStringAsFixed(1)}%',
      });
    }
    return linhas;
  }

  // Barra com a Média Q por PONTO DE ENSAIO individual — não segue a
  // hierarquia, igual à tela de análise global já existente
  // (`AnaliseTodosEsclerometriaScreen._buildGraficoBarras`).
  Future<String> _graficoBarraPontos(List<PontoEsclerometriaBruto> pontos) async {
    final grupos = <BarraGrupo>[];
    for (final p in pontos) {
      final aceitas = _aceitas(p.leituras.map((l) => l.valorQ).toList());
      if (aceitas.isEmpty) continue;
      grupos.add(BarraGrupo(rotulo: '${p.nomeElemento}\n${p.nomePonto}', valor: _mediaLista(aceitas)));
    }
    if (grupos.isEmpty) return '';
    return RelatorioChartRenderer.barrasComFaixas(grupos: grupos, tituloEixoY: 'Média Q', corBarra: _corAprovada);
  }

  // Boxplot pooled por grupo (elemento/local) — mesmo padrão genérico já
  // usado por Carbonatação/Resistividade/Potencial/Arrancamento.
  Future<String> _boxplotPor(List<PontoEsclerometriaBruto> pontos, String Function(PontoEsclerometriaBruto) chaveDe) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).addAll(_aceitas(p.leituras.map((l) => l.valorQ).toList()));
    }
    final rotulos = grupos.keys.toList();
    if (rotulos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Índice esclerométrico (Q)',
          cor: _corAprovada,
          grupos: [
            for (final r in rotulos)
              GrupoBoxplot(
                rotulo: r,
                minimo: grupos[r]!.isEmpty ? 0 : grupos[r]!.reduce(min),
                media: _mediaLista(grupos[r]!),
                maximo: grupos[r]!.isEmpty ? 0 : grupos[r]!.reduce(max),
              ),
          ],
        ),
      ],
      tituloEixoY: 'Índice esclerométrico (Q)',
    );
  }

  Future<List<Map<String, String>>> _buscarCatalogoPorNome(String tabela, Set<String> nomes, String? empresaId) async {
    if (nomes.isEmpty) return [];
    try {
      final query = _supabase.from(tabela).select('nome, descricao').inFilter('nome', nomes.toList());
      final resp = empresaId != null ? await query.or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID') : await query;
      return (resp as List).map((r) => {'nome': r['nome']?.toString() ?? '', 'descricao': r['descricao']?.toString() ?? ''}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, List<Map<String, String>>>> buscarReferencial({
    required List<String> catalogosNecessarios,
    required String estruturaId,
    required List<PontoEsclerometriaBruto> pontos,
    String? empresaId,
  }) async {
    final necessarios = catalogosNecessarios.toSet();
    final resultado = <String, List<Map<String, String>>>{};

    final catalogosEstrutura = {'tipos_estrutura', 'tipologias_estrutura', 'utilizacoes_estrutura'}.intersection(necessarios);
    if (catalogosEstrutura.isNotEmpty) {
      try {
        final e = await _supabase
            .from('estruturas')
            .select('tipos_estrutura(nome, descricao), tipologias_estrutura(nome, descricao), utilizacoes_estrutura(nome, descricao)')
            .eq('id', estruturaId)
            .maybeSingle();
        if (e != null) {
          for (final chave in catalogosEstrutura) {
            final item = e[chave] as Map<String, dynamic>?;
            if (item != null) {
              resultado[chave] = [
                {'nome': item['nome']?.toString() ?? '', 'descricao': item['descricao']?.toString() ?? ''}
              ];
            }
          }
        }
      } catch (_) {
        // Segue sem esses catálogos se a busca falhar.
      }
    }

    if (necessarios.contains('tipologias_elemento')) {
      final valores = pontos.map((p) => p.revestimento).where((v) => v.isNotEmpty).toSet();
      resultado['tipologias_elemento'] = await _buscarCatalogoPorNome('tipologias_elemento', valores, empresaId);
    }
    if (necessarios.contains('revestimentos_elemento')) {
      final valores = pontos.map((p) => p.revestimento).where((v) => v.isNotEmpty).toSet();
      resultado['revestimentos_elemento'] = await _buscarCatalogoPorNome('revestimentos_elemento', valores, empresaId);
    }

    return resultado;
  }

  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoEsclerometriaBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoBarraPontosEsclerometria)) {
      resultado[chaveGraficoBarraPontosEsclerometria] = await _graficoBarraPontos(pontos);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotElemento)) {
      resultado[chaveGraficoBoxplotElemento] = await _boxplotPor(pontos, (p) => p.tipoElemento);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotLocal)) {
      resultado[chaveGraficoBoxplotLocal] = await _boxplotPor(pontos, (p) => p.local);
    }

    return resultado;
  }
}
