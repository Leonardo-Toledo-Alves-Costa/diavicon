import 'dart:math';

import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';

// Busca e calcula os dados reais de Potencial de Corrosão pro compositor de
// relatório. Fórmulas replicadas de `analise_ponto_potencial_screen.dart`
// (linhas 213-240, única fonte — não há classe de math compartilhada) e do
// boxplot agregado de `analise_todos_potencial_screen.dart`. Igual
// Resistividade: `potencial_mv` é armazenado em módulo (positivo) no banco;
// toda estatística nega o valor (`-v.abs()`) seguindo a convenção ASTM do
// eletrodo, replicada aqui.
class RegistroPotencialReal {
  final Map<String, String> dados;
  final List<FotoRelatorio> fotos;
  const RegistroPotencialReal({required this.dados, required this.fotos});
}

class LeituraPotencialBruta {
  final int linha;
  final int coluna;
  final double? potencialMv; // valor cru do banco (módulo/positivo)
  const LeituraPotencialBruta({required this.linha, required this.coluna, required this.potencialMv});
}

class PontoPotencialBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final String eletrodo;
  final String tempoSaturacao;
  final String temperatura;
  final String espacamentoX;
  final String espacamentoY;
  final String? imagemElemento;
  final String? imagemEnsaio;
  final String? imagemElementoMapa;
  final List<LeituraPotencialBruta> leituras;
  final List<FotoRelatorio> fotos;

  const PontoPotencialBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.eletrodo,
    required this.tempoSaturacao,
    required this.temperatura,
    required this.espacamentoX,
    required this.espacamentoY,
    required this.imagemElemento,
    required this.imagemEnsaio,
    required this.imagemElementoMapa,
    required this.leituras,
    required this.fotos,
  });

  // Leituras válidas, forçadas pro sinal negativo (padrão do eletrodo) —
  // mesma conversão de `analise_ponto_potencial_screen.dart:217`.
  List<double> get leiturasValidasNegativas =>
      leituras.where((l) => l.potencialMv != null).map((l) => -l.potencialMv!.abs()).toList();
}

class PotencialModeloReportData {
  final SupabaseClient _supabase;
  PotencialModeloReportData(this._supabase);

  Future<List<PontoPotencialBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_potencial(eletrodo, tempo_saturacao, temperatura, espaçamento_x, espaçamento_y,
            imagem_elemento, imagem_ensaio, imagem_elemento_mapa,
            ponto_ensaio_potencial_leitura(linha, coluna, potencial_mv)),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoPotencialBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final potBruto = p['ponto_ensaio_potencial'];
      final pot = potBruto is List && potBruto.isNotEmpty
          ? (potBruto.first as Map<String, dynamic>)
          : (potBruto is Map ? potBruto.cast<String, dynamic>() : null);
      if (pot == null) continue; // ponto sem dados de potencial preenchidos ainda

      final leiturasResp = pot['ponto_ensaio_potencial_leitura'] as List? ?? const [];
      final leituras = leiturasResp
          .map((l) => LeituraPotencialBruta(
                linha: (l['linha'] as num?)?.toInt() ?? 0,
                coluna: (l['coluna'] as num?)?.toInt() ?? 0,
                potencialMv: (l['potencial_mv'] as num?)?.toDouble(),
              ))
          .toList();

      final fotos = <FotoRelatorio>[];
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoPotencialBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        eletrodo: pot['eletrodo']?.toString() ?? '',
        tempoSaturacao: pot['tempo_saturacao']?.toString() ?? '',
        temperatura: pot['temperatura']?.toString() ?? '',
        espacamentoX: pot['espaçamento_x']?.toString() ?? '',
        espacamentoY: pot['espaçamento_y']?.toString() ?? '',
        imagemElemento: pot['imagem_elemento']?.toString(),
        imagemEnsaio: pot['imagem_ensaio']?.toString(),
        imagemElementoMapa: pot['imagem_elemento_mapa']?.toString(),
        leituras: leituras,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  // Variância populacional (Σ(e-média)²/n) e CV = desvio/|média|*100 — só
  // calculado com mais de uma leitura e média != 0, igual a tela original.
  double _cv(List<double> v) {
    if (v.length <= 1) return 0;
    final m = _media(v);
    if (m == 0) return 0;
    final variancia = v.map((e) => pow(e - m, 2)).reduce((a, b) => a + b) / v.length;
    return sqrt(variancia) / m.abs() * 100;
  }

  // Tabela HTML da matriz de leituras (linha x coluna), cabeçalhos em
  // distância física — mesma referência de `_buildSecaoGridPotencial` em
  // `ponto_ensaio_potencial_screen.dart` (coluna: (c+1)*espX; linha: l*espY).
  // Valores exibidos crus (módulo), igual à grade de edição no app.
  String _matrizHtml(PontoPotencialBruto p) {
    if (p.leituras.isEmpty) return '';
    final maxLinha = p.leituras.map((l) => l.linha).reduce(max);
    final maxColuna = p.leituras.map((l) => l.coluna).reduce(max);
    final espX = double.tryParse(p.espacamentoX) ?? 10;
    final espY = double.tryParse(p.espacamentoY) ?? 10;

    final malha = List.generate(maxLinha + 1, (_) => List<double?>.filled(maxColuna + 1, null));
    for (final l in p.leituras) {
      if (l.potencialMv != null) malha[l.linha][l.coluna] = l.potencialMv;
    }

    final buffer = StringBuffer('<table class="resumo"><thead><tr><th></th>');
    for (var c = 0; c <= maxColuna; c++) {
      buffer.write('<th>${((c + 1) * espX).toStringAsFixed(0)} cm</th>');
    }
    buffer.write('</tr></thead><tbody>');
    for (var l = 0; l <= maxLinha; l++) {
      buffer.write('<tr><th>${(l * espY).toStringAsFixed(0)} cm</th>');
      for (var c = 0; c <= maxColuna; c++) {
        final v = malha[l][c];
        buffer.write('<td>${v == null ? '-' : '${v.toStringAsFixed(0)} mV'}</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  // Boxplot de UM ponto (todas as leituras da malha pooled numa única caixa)
  // — mesma ideia de `analise_ponto_potencial_screen.dart:314-323`
  // (`BoxAndWhiskerSeries` com um único `BoxPlotDataPotencial`).
  Future<String> _boxplotPonto(PontoPotencialBruto p) async {
    final valores = p.leiturasValidasNegativas;
    if (valores.isEmpty) return '';
    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(nome: 'Potencial (mV)', cor: Colors.deepOrange, grupos: [
          GrupoBoxplot(rotulo: p.nomePonto, minimo: valores.reduce(min), media: _media(valores), maximo: valores.reduce(max)),
        ]),
      ],
      tituloEixoY: 'Potencial (mV)',
    );
  }

  Future<RegistroPotencialReal> _montarRegistroIndividual(PontoPotencialBruto p) async {
    final valores = p.leiturasValidasNegativas;
    final media = _media(valores);
    final cv = _cv(valores);
    final menor = valores.isEmpty ? 0.0 : valores.reduce(min);
    final maior = valores.isEmpty ? 0.0 : valores.reduce(max);
    final matriz = _matrizHtml(p);
    final boxplot = await _boxplotPonto(p);

    return RegistroPotencialReal(
      dados: {
        'nome_elemento_pot': p.nomeElemento,
        'tipo_elemento_pot': p.tipoElemento,
        'local_elemento_pot': p.local,
        'revestimento_elemento_pot': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_pot': p.marcacaoImagemUrl!,
        'nome_ponto_pot': p.nomePonto,
        'valor_resultado_pot': p.valorResultado,
        'eletrodo_pot': p.eletrodo,
        'tempo_saturacao_pot': p.tempoSaturacao,
        'temperatura_pot': p.temperatura,
        if (p.imagemElemento != null && p.imagemElemento!.isNotEmpty) 'imagem_elemento_pot': p.imagemElemento!,
        if (p.imagemEnsaio != null && p.imagemEnsaio!.isNotEmpty) 'imagem_ensaio_pot': p.imagemEnsaio!,
        if (p.imagemElementoMapa != null && p.imagemElementoMapa!.isNotEmpty) 'imagem_elemento_mapa_pot': p.imagemElementoMapa!,
        if (matriz.isNotEmpty) 'matriz_leituras_pot': matriz,
        'media_potencial_pot': '${media.toStringAsFixed(0)} mV',
        'cv_potencial_pot': '${cv.toStringAsFixed(1)}%',
        'menor_potencial_pot': '${menor.toStringAsFixed(0)} mV',
        'maior_potencial_pot': '${maior.toStringAsFixed(0)} mV',
        if (boxplot.isNotEmpty) 'boxplot_potencial_pot': boxplot,
      },
      fotos: p.fotos,
    );
  }

  Future<List<RegistroPotencialReal>> montarRegistros(List<PontoPotencialBruto> pontos) async {
    final registros = <RegistroPotencialReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoPotencialBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoPotencialBruto>>{};
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
      final valores = entrada.value.expand((p) => p.leiturasValidasNegativas).toList();
      // Eletrodo/tempo de saturação/temperatura são config do ensaio, não
      // estatística — concatena os valores distintos do grupo.
      final eletrodos = entrada.value.map((p) => p.eletrodo).where((v) => v.isNotEmpty).toSet().join(', ');
      final saturacoes = entrada.value.map((p) => p.tempoSaturacao).where((v) => v.isNotEmpty).toSet().join(', ');
      final temperaturas = entrada.value.map((p) => p.temperatura).where((v) => v.isNotEmpty).toSet().join(', ');
      linhas.add({
        'local_grupo_pot': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_pot': rotulos[entrada.key]!.tipo,
        'eletrodo_grupo_pot': eletrodos,
        'tempo_saturacao_grupo_pot': saturacoes,
        'temperatura_grupo_pot': temperaturas,
        'media_potencial_grupo_pot': '${_media(valores).toStringAsFixed(0)} mV',
        'cv_potencial_grupo_pot': '${_cv(valores).toStringAsFixed(1)}%',
        'maior_potencial_grupo_pot': valores.isEmpty ? '-' : '${valores.reduce(max).toStringAsFixed(0)} mV',
        'menor_potencial_grupo_pot': valores.isEmpty ? '-' : '${valores.reduce(min).toStringAsFixed(0)} mV',
      });
    }
    return linhas;
  }

  // Boxplot por grupo (elemento/local): todas as leituras dos pontos do
  // grupo pooled numa única caixa por grupo — mesmo padrão genérico já usado
  // por Carbonatação/Resistividade (`chaveGraficoBoxplotElemento/Local`).
  Future<String> _boxplotPor(List<PontoPotencialBruto> pontos, String Function(PontoPotencialBruto) chaveDe) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).addAll(p.leiturasValidasNegativas);
    }
    final rotulos = grupos.keys.toList();
    if (rotulos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Potencial (mV)',
          cor: Colors.deepOrange,
          grupos: [
            for (final r in rotulos)
              GrupoBoxplot(
                rotulo: r,
                minimo: grupos[r]!.isEmpty ? 0 : grupos[r]!.reduce(min),
                media: _media(grupos[r]!),
                maximo: grupos[r]!.isEmpty ? 0 : grupos[r]!.reduce(max),
              ),
          ],
        ),
      ],
      tituloEixoY: 'Potencial (mV)',
    );
  }

  // Mesmo mecanismo de `ResistividadeModeloReportData.buscarReferencial`.
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
    required List<PontoPotencialBruto> pontos,
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
    required List<PontoPotencialBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoBoxplotElemento)) {
      resultado[chaveGraficoBoxplotElemento] = await _boxplotPor(pontos, (p) => p.tipoElemento);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotLocal)) {
      resultado[chaveGraficoBoxplotLocal] = await _boxplotPor(pontos, (p) => p.local);
    }

    return resultado;
  }
}
