import 'dart:math';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../utils/classificacao_resistividade.dart';

// Busca e calcula os dados reais de Resistividade Elétrica Superficial pro
// compositor de relatório. As fórmulas replicam o conjunto usado pela tela
// de análise GLOBAL/agregada (`models/analise_resistividade_model.dart` —
// "Modelo A" na pesquisa) — o app tem hoje 3 outras cópias quase idênticas
// dessas fórmulas com pequenas diferenças de `<`/`<=` e rótulos entre si
// (nenhuma delas centralizada numa classe de math compartilhada); escolhi
// uma única fonte pra não somar mais uma divergência.
class RegistroResistividadeReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroResistividadeReal({required this.dados, required this.leituras, required this.fotos});
}

class LeituraBruta {
  final String nomeLeitura;
  final double resistividade;
  final String hora;
  const LeituraBruta({required this.nomeLeitura, required this.resistividade, required this.hora});
}

class PontoResistBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final List<LeituraBruta> leituras;
  final List<FotoRelatorio> fotos;
  final String? marcacaoLeituraUrl;

  const PontoResistBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.leituras,
    required this.fotos,
    required this.marcacaoLeituraUrl,
  });

  // "Últimos valores": agrupa as leituras por ponto de leitura
  // (`nome_leitura`) e pega só a mais recente (por `hora`) de cada grupo —
  // mesma lógica já usada na tela de análise por ponto (ver pesquisa).
  List<double> get ultimosValores {
    final porGrupo = <String, List<LeituraBruta>>{};
    for (final l in leituras) {
      porGrupo.putIfAbsent(l.nomeLeitura, () => []).add(l);
    }
    final valores = <double>[];
    for (final grupo in porGrupo.values) {
      final ordenado = [...grupo]..sort((a, b) => a.hora.compareTo(b.hora));
      valores.add(ordenado.last.resistividade);
    }
    return valores;
  }
}

class ResistividadeModeloReportData {
  final SupabaseClient _supabase;
  ResistividadeModeloReportData(this._supabase);

  Future<List<PontoResistBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase
        .from('pontos_ensaios_geral')
        .select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_resistividade_leitura(nome_leitura, resistividade, hora),
          galeria_ponto_ensaio_resistividade(imagem_url, referencia),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''')
        .eq('projeto_id', projetoId)
        .eq('elementos_estruturais.estrutura_id', estruturaId)
        .eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoResistBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;

      final leiturasResp = p['ponto_ensaio_resistividade_leitura'] as List? ?? const [];
      final leituras = leiturasResp
          .map((l) => LeituraBruta(
                nomeLeitura: l['nome_leitura']?.toString() ?? '',
                resistividade: (l['resistividade'] as num?)?.toDouble() ?? 0,
                hora: l['hora']?.toString() ?? '00:00',
              ))
          .toList();

      final fotos = <FotoRelatorio>[];
      String? marcacaoLeituraUrl;
      final galeria = p['galeria_ponto_ensaio_resistividade'] as List? ?? const [];
      for (final g in galeria) {
        final url = g['imagem_url']?.toString();
        if (url == null || url.isEmpty) continue;
        final referencia = g['referencia']?.toString();
        if (referencia == '4') {
          // "Grid com pontos": a marcação dos pontos de leitura já vem
          // pronta (PNG gerado no app na hora de salvar o ponto).
          marcacaoLeituraUrl = url;
          continue;
        }
        final legenda = switch (referencia) {
          '1' => 'Elemento',
          '2' => 'Realizando ensaio',
          '3' => 'Grid',
          _ => '',
        };
        fotos.add(FotoRelatorio(url: url, descricao: legenda));
      }
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoResistBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        leituras: leituras,
        fotos: fotos,
        marcacaoLeituraUrl: marcacaoLeituraUrl,
      ));
    }
    return pontos;
  }

  // --- Riscos/taxas: fonte unica (ClassificacaoResistividade). O relatorio
  // tinha copia propria e divergia da tela do app para a mesma leitura. ---
  String _riscoCorrosao(double media) => ClassificacaoResistividade.risco.classificar(media)?.texto ?? '-';

  String _taxaCorrosao(double media) => ClassificacaoResistividade.taxa.classificar(media)?.texto ?? '-';

  String _permissividade(double media) => ClassificacaoResistividade.permissividade.classificar(media)?.texto ?? '-';

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  double _desvioPadrao(List<double> v) {
    if (v.isEmpty) return 0;
    final m = _media(v);
    final variancia = v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length;
    return sqrt(variancia);
  }

  double _coefVariacao(List<double> v) {
    final m = _media(v);
    return m == 0 ? 0 : _desvioPadrao(v) / m * 100;
  }

  int _horaParaMinutos(String hora) {
    final partes = hora.split(':');
    if (partes.length < 2) return 0;
    final h = int.tryParse(partes[0]) ?? 0;
    final m = int.tryParse(partes[1]) ?? 0;
    return h * 60 + m;
  }

  // Gráfico "resistividade dos pontos ao longo do tempo": uma curva por
  // ponto de leitura (`nome_leitura`), eixo X = minutos decorridos desde a
  // leitura mais antiga do PONTO INTEIRO (eixo compartilhado entre as
  // curvas), mesma ideia da tela de análise por ponto.
  Future<String> _graficoResistividadeTempo(PontoResistBruto p) async {
    if (p.leituras.isEmpty) return '';
    final horaInicial = p.leituras.map((l) => _horaParaMinutos(l.hora)).reduce((a, b) => a < b ? a : b);

    final porGrupo = <String, List<LeituraBruta>>{};
    for (final l in p.leituras) {
      porGrupo.putIfAbsent(l.nomeLeitura, () => []).add(l);
    }

    const paleta = [
      Color(0xFF1E88E5),
      Color(0xFFD81B60),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF8E24AA),
      Color(0xFF00ACC1),
    ];

    final series = <SerieLinha>[];
    var i = 0;
    for (final entrada in porGrupo.entries) {
      final ordenado = [...entrada.value]..sort((a, b) => a.hora.compareTo(b.hora));
      final pontosGrafico = ordenado.map((l) {
        var deltaMin = _horaParaMinutos(l.hora) - horaInicial;
        if (deltaMin < 0) deltaMin += 24 * 60;
        return PontoGrafico(deltaMin.toDouble(), l.resistividade);
      }).toList();
      series.add(SerieLinha(nome: entrada.key, pontos: pontosGrafico, cor: paleta[i % paleta.length]));
      i++;
    }

    return RelatorioChartRenderer.linhaComFaixa(
      series: series,
      tituloEixoX: 'Tempo (min)',
      tituloEixoY: 'Resistividade (KΩ.cm)',
    );
  }

  Future<RegistroResistividadeReal> _montarRegistroIndividual(PontoResistBruto p) async {
    final ultimos = p.ultimosValores;
    final media = _media(ultimos);
    final cv = _coefVariacao(ultimos);
    final menor = ultimos.isEmpty ? 0.0 : ultimos.reduce(min);
    final maior = ultimos.isEmpty ? 0.0 : ultimos.reduce(max);

    final grafico = await _graficoResistividadeTempo(p);

    final porGrupoLeitura = <String, List<double>>{};
    for (final l in p.leituras) {
      porGrupoLeitura.putIfAbsent(l.nomeLeitura, () => []).add(l.resistividade);
    }
    final leiturasDados = porGrupoLeitura.entries
        .map((e) => <String, String>{
              'nome_leitura_resist': e.key,
              'menor_leitura_resist': '${e.value.reduce(min).toStringAsFixed(1)} KΩ.cm',
            })
        .toList();

    return RegistroResistividadeReal(
      dados: {
        'nome_elemento_resist': p.nomeElemento,
        'tipo_elemento_resist': p.tipoElemento,
        'local_elemento_resist': p.local,
        'revestimento_elemento_resist': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_resist': p.marcacaoImagemUrl!,
        if (p.marcacaoLeituraUrl != null && p.marcacaoLeituraUrl!.isNotEmpty) 'marcacao_leitura_resist': p.marcacaoLeituraUrl!,
        'nome_ponto_resist': p.nomePonto,
        'valor_resultado_resist': p.valorResultado,
        'menor_resistividade_resist': '${menor.toStringAsFixed(1)} KΩ.cm',
        'maior_resistividade_resist': '${maior.toStringAsFixed(1)} KΩ.cm',
        'media_resistividade_resist': '${media.toStringAsFixed(1)} KΩ.cm',
        'cv_resistividade_resist': '${cv.toStringAsFixed(1)}%',
        if (grafico.isNotEmpty) 'grafico_resistividade_tempo_resist': grafico,
        'risco_corrosao_resist': _riscoCorrosao(media),
        'taxa_corrosao_resist': _taxaCorrosao(media),
        'permissividade_resist': _permissividade(media),
      },
      leituras: leiturasDados,
      fotos: p.fotos,
    );
  }

  Future<List<RegistroResistividadeReal>> montarRegistros(List<PontoResistBruto> pontos) async {
    final registros = <RegistroResistividadeReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoResistBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoResistBruto>>{};
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
      final valores = entrada.value.expand((p) => p.ultimosValores).toList();
      final media = _media(valores);
      linhas.add({
        'local_grupo_resist': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_resist': rotulos[entrada.key]!.tipo,
        'media_resistividade_grupo_resist': '${media.toStringAsFixed(1)} KΩ.cm',
        'cv_resistividade_grupo_resist': '${_coefVariacao(valores).toStringAsFixed(1)}%',
        'maior_resistividade_grupo_resist': valores.isEmpty ? '-' : '${valores.reduce(max).toStringAsFixed(1)} KΩ.cm',
        'menor_resistividade_grupo_resist': valores.isEmpty ? '-' : '${valores.reduce(min).toStringAsFixed(1)} KΩ.cm',
        'risco_corrosao_grupo_resist': _riscoCorrosao(media),
        'taxa_corrosao_grupo_resist': _taxaCorrosao(media),
        'permissividade_grupo_resist': _permissividade(media),
      });
    }
    return linhas;
  }

  // Faixas de fundo do gráfico "distribuição por risco" — mesmas fronteiras
  // de `_riscoCorrosao`. `chaveGraficoDistribuicaoRisco*` mostram a
  // resistividade MÉDIA de cada grupo; a cor de fundo indica a zona.
  static const List<FaixaFundo> _faixasRisco = [
    FaixaFundo(de: 0, ate: 15, cor: Color(0xFFD32F2F), rotulo: 'Muito Alto'),
    FaixaFundo(de: 15, ate: 20, cor: Color(0xFFF57C00), rotulo: 'Alto'),
    FaixaFundo(de: 20, ate: 55, cor: Color(0xFFFBC02D), rotulo: 'Moderado'),
    FaixaFundo(de: 55, ate: 80, cor: Color(0xFF7CB342), rotulo: 'Baixo'),
    FaixaFundo(de: 80, ate: 300, cor: Color(0xFF388E3C), rotulo: 'Desprezível'),
  ];

  Future<String> _distribuicaoRiscoPor(List<PontoResistBruto> pontos, String Function(PontoResistBruto) chaveDe) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).addAll(p.ultimosValores);
    }
    if (grupos.isEmpty) return '';

    final barras = grupos.entries.map((e) => BarraGrupo(rotulo: e.key, valor: _media(e.value))).toList();
    return RelatorioChartRenderer.barrasComFaixas(
      grupos: barras,
      faixas: _faixasRisco,
      tituloEixoY: 'Resistividade (KΩ.cm)',
      corBarra: Colors.blueGrey,
    );
  }

  Future<String> _boxplotPor(List<PontoResistBruto> pontos, String Function(PontoResistBruto) chaveDe) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).addAll(p.ultimosValores);
    }
    final rotulos = grupos.keys.toList();
    if (rotulos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Resistividade (KΩ.cm)',
          cor: Colors.blueGrey,
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
      tituloEixoY: 'Resistividade (KΩ.cm)',
    );
  }

  // Mesmo mecanismo de `CarbonatacaoModeloReportData.buscarReferencial`:
  // Estrutura via embed FK; Tipologia/Revestimento de elemento casam por
  // texto com `elementos_estruturais` (não há Local/Sistema/Tipos de
  // elemento por FK nem Anomalias pra este ensaio).
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
    required List<PontoResistBruto> pontos,
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
    required List<PontoResistBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoDistribuicaoRiscoElemento)) {
      resultado[chaveGraficoDistribuicaoRiscoElemento] = await _distribuicaoRiscoPor(pontos, (p) => p.tipoElemento);
    }
    if (graficosSelecionados.contains(chaveGraficoDistribuicaoRiscoLocal)) {
      resultado[chaveGraficoDistribuicaoRiscoLocal] = await _distribuicaoRiscoPor(pontos, (p) => p.local);
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
