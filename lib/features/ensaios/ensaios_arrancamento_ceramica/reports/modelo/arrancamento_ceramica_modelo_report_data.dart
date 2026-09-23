import 'dart:math';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/ponto_arrancamento_ceramica_model.dart' show CatalogoRupturasCeramica;

// Busca e calcula os dados reais de Arrancamento em Placa Cerâmica pro
// compositor de relatório. Praticamente idêntico a
// `ArrancamentoModeloReportData` (Arrancamento em Argamassa) — as duas
// variantes compartilham as MESMAS tabelas (`ponto_ensaio_arrancamento*`),
// só filtradas por `tipo_ensaio_id` diferente. Diferenças reais: sem
// diâmetro (a leitura só grava `area` diretamente, ver
// `PontoLeituraCeramicaModel.tensaoCalculada`) e sem campo de substrato.
class RegistroArrancamentoCeramicaReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroArrancamentoCeramicaReal({required this.dados, required this.leituras, required this.fotos});
}

class RupturaCeramicaBruta {
  final String tipoRuptura; // título completo (casa com CatalogoRupturasCeramica.titulo)
  final double porcentagem;
  const RupturaCeramicaBruta({required this.tipoRuptura, required this.porcentagem});
}

class LeituraArrancamentoCeramicaBruta {
  final String nome;
  final String? imagemEnsaio;
  final String? imagemRuptura;
  final double? area;
  final double? carga;
  final List<RupturaCeramicaBruta> rupturas;

  const LeituraArrancamentoCeramicaBruta({
    required this.nome,
    required this.imagemEnsaio,
    required this.imagemRuptura,
    required this.area,
    required this.carga,
    required this.rupturas,
  });

  double get tensaoCalculada {
    if (area == null || area! <= 0 || carga == null || carga! <= 0) return 0.0;
    return carga! / area!;
  }

  String get resumoRupturas {
    final preenchidas = rupturas.where((r) => r.porcentagem > 0).toList();
    if (preenchidas.isEmpty) return 'Não definida';
    return preenchidas.map((r) => '${r.porcentagem.toStringAsFixed(0)}% ${r.tipoRuptura}').join(' | ');
  }
}

class PontoArrancamentoCeramicaBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final String? imagemRegiao;
  final String? imagemColagem;
  final String temperatura;
  final String umidade;
  final String idadeRevestimento;
  final String colaUtilizada;
  final List<LeituraArrancamentoCeramicaBruta> leituras;
  final List<FotoRelatorio> fotos;

  const PontoArrancamentoCeramicaBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.imagemRegiao,
    required this.imagemColagem,
    required this.temperatura,
    required this.umidade,
    required this.idadeRevestimento,
    required this.colaUtilizada,
    required this.leituras,
    required this.fotos,
  });

  List<double> get tensoesValidas => leituras.map((l) => l.tensaoCalculada).where((t) => t > 0).toList();
}

class ArrancamentoCeramicaModeloReportData {
  final SupabaseClient _supabase;
  ArrancamentoCeramicaModeloReportData(this._supabase);

  Future<List<PontoArrancamentoCeramicaBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_arrancamento(imagem_regiao, imagem_colagem, temperatura, umidade, idade_revestimento, cola_utilizada,
            ponto_ensaio_arrancamento_leitura(nome, imagem_ensaio, imgem_ruptura, area, carga,
              ponto_ensaio_arrancamento_ruptura(tipo_ruptura, porcentagem))),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoArrancamentoCeramicaBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final arrBruto = p['ponto_ensaio_arrancamento'];
      final arr = arrBruto is List && arrBruto.isNotEmpty
          ? (arrBruto.first as Map<String, dynamic>)
          : (arrBruto is Map ? arrBruto.cast<String, dynamic>() : null);
      if (arr == null) continue; // ponto sem dados de arrancamento preenchidos ainda

      final leiturasResp = arr['ponto_ensaio_arrancamento_leitura'] as List? ?? const [];
      final leituras = leiturasResp.map((l) {
        final rupturasResp = l['ponto_ensaio_arrancamento_ruptura'] as List? ?? const [];
        final rupturas = rupturasResp
            .map((r) => RupturaCeramicaBruta(
                  tipoRuptura: r['tipo_ruptura']?.toString() ?? '',
                  porcentagem: (r['porcentagem'] as num?)?.toDouble() ?? 0,
                ))
            .toList();
        return LeituraArrancamentoCeramicaBruta(
          nome: l['nome']?.toString() ?? '',
          imagemEnsaio: l['imagem_ensaio']?.toString(),
          imagemRuptura: l['imgem_ruptura']?.toString(),
          area: (l['area'] as num?)?.toDouble(),
          carga: (l['carga'] as num?)?.toDouble(),
          rupturas: rupturas,
        );
      }).toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));

      final fotos = <FotoRelatorio>[];
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoArrancamentoCeramicaBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        imagemRegiao: arr['imagem_regiao']?.toString(),
        imagemColagem: arr['imagem_colagem']?.toString(),
        temperatura: arr['temperatura']?.toString() ?? '',
        umidade: arr['umidade']?.toString() ?? '',
        idadeRevestimento: arr['idade_revestimento']?.toString() ?? '',
        colaUtilizada: arr['cola_utilizada']?.toString() ?? '',
        leituras: leituras,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  double _cv(List<double> v) {
    if (v.length <= 1) return 0;
    final m = _media(v);
    if (m == 0) return 0;
    final variancia = v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length;
    return sqrt(variancia) / m * 100;
  }

  String _rupturaPredominante(List<LeituraArrancamentoCeramicaBruta> leituras) {
    final somas = <String, double>{};
    for (final l in leituras) {
      for (final r in l.rupturas) {
        if (r.porcentagem <= 0) continue;
        somas[r.tipoRuptura] = (somas[r.tipoRuptura] ?? 0) + r.porcentagem;
      }
    }
    if (somas.isEmpty) return '-';
    return somas.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // Tipos de ruptura agrupados com a % média de cada um entre as leituras
  // recebidas — mesma normalização do gráfico de pizza por ponto de
  // `analise_ponto_arrancamento_ceramica_screen.dart` (`_gerarDadosPizza`),
  // formatado como `LeituraArrancamentoCeramicaBruta.resumoRupturas`
  // ("60% Cerâmica | 40% Argamassa"), ordenado da maior pra menor porcentagem.
  String _rupturaAgrupada(List<LeituraArrancamentoCeramicaBruta> leituras) {
    final somas = <String, double>{};
    var totalValidas = 0;
    for (final l in leituras) {
      final preenchidas = l.rupturas.where((r) => r.porcentagem > 0).toList();
      if (preenchidas.isEmpty) continue;
      totalValidas++;
      for (final r in preenchidas) {
        somas[r.tipoRuptura] = (somas[r.tipoRuptura] ?? 0) + r.porcentagem;
      }
    }
    if (totalValidas == 0) return 'Não definida';
    final entradas = somas.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entradas.map((e) => '${(e.value / totalValidas).toStringAsFixed(0)}% ${e.key}').join(' | ');
  }

  // Paleta por SIGLA — usa o catálogo canônico `CatalogoRupturasCeramica.itens`
  // (título -> sigla). Não reaproveita o mapeamento local de
  // `analise_ponto_arrancamento_ceramica_screen.dart`: aquele switch usa
  // siglas ('S/E', 'AC/PC'...) que não batem com as siglas reais do catálogo
  // ('S / A', 'A / C'...), então praticamente nunca casava — inconsistência
  // pré-existente do app, não replicada aqui.
  static const Map<String, Color> _paletaRuptura = {
    'S': Color(0xFF795548),
    'S / A': Color(0xFFA1887F),
    'A': Color(0xFFFFB300),
    'A / C': Color(0xFFFF8A65),
    'C': Color(0xFFD84315),
    'F': Color(0xFFE53935),
  };

  Color _corRuptura(String tituloRuptura) {
    final item = CatalogoRupturasCeramica.itens.where((c) => c.titulo == tituloRuptura).firstOrNull;
    return _paletaRuptura[item?.sigla] ?? Colors.blueGrey;
  }

  static const List<Color> _paletaGrupos = [
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
    Color(0xFFC0CA33),
  ];

  Future<String> _graficoTensaoPorLeitura(PontoArrancamentoCeramicaBruto p) async {
    final grupos = <BarraSegmentadaGrupo>[];
    for (final l in p.leituras) {
      final tensao = l.tensaoCalculada;
      if (tensao <= 0) continue;
      final preenchidas = l.rupturas.where((r) => r.porcentagem > 0).toList();
      if (preenchidas.isEmpty) {
        grupos.add(BarraSegmentadaGrupo(rotulo: l.nome, segmentos: [
          SegmentoBarra(rotulo: 'Não definida', valor: tensao, cor: Colors.grey),
        ]));
        continue;
      }
      grupos.add(BarraSegmentadaGrupo(
        rotulo: l.nome,
        segmentos: [
          for (final r in preenchidas) SegmentoBarra(rotulo: r.tipoRuptura, valor: tensao * (r.porcentagem / 100.0), cor: _corRuptura(r.tipoRuptura)),
        ],
      ));
    }
    if (grupos.isEmpty) return '';
    return RelatorioChartRenderer.barrasSegmentadas(grupos: grupos, tituloEixoY: 'Tensão (MPa)');
  }

  Future<RegistroArrancamentoCeramicaReal> _montarRegistroIndividual(PontoArrancamentoCeramicaBruto p) async {
    final tensoes = p.tensoesValidas;
    final media = _media(tensoes);
    final cv = _cv(tensoes);
    final menor = tensoes.isEmpty ? 0.0 : tensoes.reduce(min);
    final maior = tensoes.isEmpty ? 0.0 : tensoes.reduce(max);
    final grafico = await _graficoTensaoPorLeitura(p);

    final leiturasDados = p.leituras
        .map((l) => <String, String>{
              'nome_leitura_cer': l.nome,
              if (l.imagemEnsaio != null && l.imagemEnsaio!.isNotEmpty) 'imagem_ensaio_leitura_cer': l.imagemEnsaio!,
              if (l.imagemRuptura != null && l.imagemRuptura!.isNotEmpty) 'imagem_ruptura_leitura_cer': l.imagemRuptura!,
              'area_leitura_cer': l.area != null ? '${l.area!.toStringAsFixed(1)} mm²' : '-',
              'carga_leitura_cer': l.carga != null ? '${l.carga!.toStringAsFixed(2)} KN' : '-',
              'tensao_leitura_cer': '${l.tensaoCalculada.toStringAsFixed(2)} MPa',
              'ruptura_leitura_cer': l.resumoRupturas,
            })
        .toList();

    return RegistroArrancamentoCeramicaReal(
      dados: {
        'nome_elemento_cer': p.nomeElemento,
        'tipo_elemento_cer': p.tipoElemento,
        'local_elemento_cer': p.local,
        'revestimento_elemento_cer': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_cer': p.marcacaoImagemUrl!,
        'nome_ponto_cer': p.nomePonto,
        'valor_resultado_cer': p.valorResultado,
        if (p.imagemRegiao != null && p.imagemRegiao!.isNotEmpty) 'imagem_regiao_cer': p.imagemRegiao!,
        if (p.imagemColagem != null && p.imagemColagem!.isNotEmpty) 'imagem_colagem_cer': p.imagemColagem!,
        'temperatura_cer': p.temperatura,
        'umidade_cer': p.umidade,
        'idade_revestimento_cer': p.idadeRevestimento,
        'cola_utilizada_cer': p.colaUtilizada,
        'media_tensao_cer': '${media.toStringAsFixed(2)} MPa',
        'maior_tensao_cer': '${maior.toStringAsFixed(2)} MPa',
        'menor_tensao_cer': '${menor.toStringAsFixed(2)} MPa',
        'cv_tensao_cer': '${cv.toStringAsFixed(1)}%',
        'ruptura_tipos_cer': _rupturaAgrupada(p.leituras),
        if (grafico.isNotEmpty) 'grafico_tensao_ruptura_cer': grafico,
      },
      leituras: leiturasDados,
      fotos: p.fotos,
    );
  }

  Future<List<RegistroArrancamentoCeramicaReal>> montarRegistros(List<PontoArrancamentoCeramicaBruto> pontos) async {
    final registros = <RegistroArrancamentoCeramicaReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoArrancamentoCeramicaBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoArrancamentoCeramicaBruto>>{};
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
      final leiturasGrupo = entrada.value.expand((p) => p.leituras).toList();
      final tensoes = entrada.value.expand((p) => p.tensoesValidas).toList();
      final temperaturas = entrada.value.map((p) => p.temperatura).where((v) => v.isNotEmpty).toSet().join(', ');
      final umidades = entrada.value.map((p) => p.umidade).where((v) => v.isNotEmpty).toSet().join(', ');
      final idades = entrada.value.map((p) => p.idadeRevestimento).where((v) => v.isNotEmpty).toSet().join(', ');
      final colas = entrada.value.map((p) => p.colaUtilizada).where((v) => v.isNotEmpty).toSet().join(', ');
      linhas.add({
        'local_grupo_cer': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_cer': rotulos[entrada.key]!.tipo,
        'temperatura_grupo_cer': temperaturas,
        'umidade_grupo_cer': umidades,
        'idade_revestimento_grupo_cer': idades,
        'cola_utilizada_grupo_cer': colas,
        'media_tensao_grupo_cer': '${_media(tensoes).toStringAsFixed(2)} MPa',
        'cv_tensao_grupo_cer': '${_cv(tensoes).toStringAsFixed(1)}%',
        'menor_tensao_grupo_cer': tensoes.isEmpty ? '-' : '${tensoes.reduce(min).toStringAsFixed(2)} MPa',
        'maior_tensao_grupo_cer': tensoes.isEmpty ? '-' : '${tensoes.reduce(max).toStringAsFixed(2)} MPa',
        'ruptura_predominante_grupo_cer': _rupturaPredominante(leiturasGrupo),
      });
    }
    return linhas;
  }

  Map<String, List<PontoArrancamentoCeramicaBruto>> _agruparPorElemento(List<PontoArrancamentoCeramicaBruto> pontos) {
    final grupos = <String, List<PontoArrancamentoCeramicaBruto>>{};
    for (final p in pontos) {
      grupos.putIfAbsent('${p.local}|${p.nomeElemento}', () => []).add(p);
    }
    return grupos;
  }

  Future<String> _graficoBarraTensaoElementos(List<PontoArrancamentoCeramicaBruto> pontos) async {
    final porElemento = _agruparPorElemento(pontos);
    if (porElemento.isEmpty) return '';

    final grupos = <BarraSegmentadaGrupo>[];
    for (final entrada in porElemento.entries) {
      final pontosDoElemento = entrada.value;
      final leituras = pontosDoElemento.expand((p) => p.leituras).toList();
      final tensoes = pontosDoElemento.expand((p) => p.tensoesValidas).toList();
      final media = _media(tensoes);
      if (media <= 0) continue;

      final somas = <String, double>{};
      for (final l in leituras) {
        for (final r in l.rupturas) {
          if (r.porcentagem <= 0) continue;
          somas[r.tipoRuptura] = (somas[r.tipoRuptura] ?? 0) + r.porcentagem;
        }
      }
      final totalSoma = somas.values.fold(0.0, (a, b) => a + b);
      final nomeElemento = pontosDoElemento.first.nomeElemento;

      if (totalSoma <= 0) {
        grupos.add(BarraSegmentadaGrupo(rotulo: nomeElemento, segmentos: [SegmentoBarra(rotulo: 'Não definida', valor: media, cor: Colors.grey)]));
        continue;
      }
      grupos.add(BarraSegmentadaGrupo(
        rotulo: nomeElemento,
        segmentos: [
          for (final s in somas.entries) SegmentoBarra(rotulo: s.key, valor: media * (s.value / totalSoma), cor: _corRuptura(s.key)),
        ],
      ));
    }
    if (grupos.isEmpty) return '';
    return RelatorioChartRenderer.barrasSegmentadas(grupos: grupos, tituloEixoY: 'Tensão média (MPa)');
  }

  Future<String> _boxplotPorLocal(List<PontoArrancamentoCeramicaBruto> pontos) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(p.local, () => []).addAll(p.tensoesValidas);
    }
    final rotulos = grupos.keys.toList();
    if (rotulos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Tensão (MPa)',
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
      tituloEixoY: 'Tensão (MPa)',
    );
  }

  Future<String> _boxplotElementosEspecificos(List<PontoArrancamentoCeramicaBruto> pontos) async {
    final porElemento = _agruparPorElemento(pontos);
    if (porElemento.isEmpty) return '';

    final coresPorTipo = <String, Color>{};
    var i = 0;
    final grupos = <GrupoBoxplot>[];
    for (final entrada in porElemento.entries) {
      final pontosDoElemento = entrada.value;
      final tensoes = pontosDoElemento.expand((p) => p.tensoesValidas).toList();
      if (tensoes.isEmpty) continue;
      final tipo = pontosDoElemento.first.tipoElemento;
      final cor = coresPorTipo.putIfAbsent(tipo, () => _paletaGrupos[i++ % _paletaGrupos.length]);
      grupos.add(GrupoBoxplot(
        rotulo: pontosDoElemento.first.nomeElemento,
        minimo: tensoes.reduce(min),
        media: _media(tensoes),
        maximo: tensoes.reduce(max),
        cor: cor,
      ));
    }
    if (grupos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [SerieBoxplot(nome: 'Tensão (MPa)', cor: Colors.blueGrey, grupos: grupos)],
      tituloEixoY: 'Tensão (MPa)',
      legendaOverride: coresPorTipo.entries.map((e) => MapEntry(e.key, e.value)).toList(),
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
    required List<PontoArrancamentoCeramicaBruto> pontos,
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
    required List<PontoArrancamentoCeramicaBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoBarraTensaoElementos)) {
      resultado[chaveGraficoBarraTensaoElementos] = await _graficoBarraTensaoElementos(pontos);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotElementosEspecificos)) {
      resultado[chaveGraficoBoxplotElementosEspecificos] = await _boxplotElementosEspecificos(pontos);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotLocal)) {
      resultado[chaveGraficoBoxplotLocal] = await _boxplotPorLocal(pontos);
    }

    return resultado;
  }
}
