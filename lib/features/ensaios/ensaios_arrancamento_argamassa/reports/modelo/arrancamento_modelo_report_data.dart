import 'dart:math';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/ponto_arrancamento_model.dart' show CatalogoRupturas;

// Busca e calcula os dados reais de Arrancamento em Argamassa pro compositor
// de relatório. Fórmulas replicadas de `PontoArrancamentoLeituraModel`/
// `PontoArrancamentoModel` (models/ponto_arrancamento_model.dart) — a mesma
// cadeia diâmetro->área->tensão usada no app (não a versão simplificada de
// `analise_arrancamento_model.dart`, que ignora o cálculo de área a partir
// do diâmetro quando `area` não vem preenchida).
class RegistroArrancamentoReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroArrancamentoReal({required this.dados, required this.leituras, required this.fotos});
}

class RupturaBruta {
  final String tipoRuptura; // título completo (casa com CatalogoRupturas.titulo)
  final double porcentagem;
  const RupturaBruta({required this.tipoRuptura, required this.porcentagem});
}

class LeituraArrancamentoBruta {
  final String nome;
  final String? imagemEnsaio;
  final String? imagemRuptura;
  final double? d1;
  final double? d2;
  final double? area;
  final double? carga;
  final List<RupturaBruta> rupturas;

  const LeituraArrancamentoBruta({
    required this.nome,
    required this.imagemEnsaio,
    required this.imagemRuptura,
    required this.d1,
    required this.d2,
    required this.area,
    required this.carga,
    required this.rupturas,
  });

  double get diametroMedio {
    if (d1 != null && d2 != null && d1! > 0 && d2! > 0) return (d1! + d2!) / 2.0;
    if (d1 != null && d1! > 0) return d1!;
    return 0.0;
  }

  double get areaCalculada {
    if (area != null && area! > 0) return area!;
    final dm = diametroMedio;
    if (dm <= 0) return 0.0;
    return pi * pow(dm / 2.0, 2);
  }

  double get tensaoCalculada {
    final a = areaCalculada;
    if (a <= 0 || carga == null || carga! <= 0) return 0.0;
    return carga! / a;
  }

  String get resumoRupturas {
    final preenchidas = rupturas.where((r) => r.porcentagem > 0).toList();
    if (preenchidas.isEmpty) return 'Não definida';
    return preenchidas.map((r) => '${r.porcentagem.toStringAsFixed(0)}% ${r.tipoRuptura}').join(' | ');
  }
}

class PontoArrancamentoBruto {
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
  final String tipoSubstrato;
  final List<LeituraArrancamentoBruta> leituras;
  final List<FotoRelatorio> fotos;

  const PontoArrancamentoBruto({
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
    required this.tipoSubstrato,
    required this.leituras,
    required this.fotos,
  });

  List<double> get tensoesValidas => leituras.map((l) => l.tensaoCalculada).where((t) => t > 0).toList();
}

class ArrancamentoModeloReportData {
  final SupabaseClient _supabase;
  ArrancamentoModeloReportData(this._supabase);

  Future<List<PontoArrancamentoBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_arrancamento(imagem_regiao, imagem_colagem, temperatura, umidade, idade_revestimento, cola_utilizada, tipo_substrato,
            ponto_ensaio_arrancamento_leitura(nome, imagem_ensaio, imgem_ruptura, d1, d2, area, carga,
              ponto_ensaio_arrancamento_ruptura(tipo_ruptura, porcentagem))),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoArrancamentoBruto>[];
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
            .map((r) => RupturaBruta(
                  tipoRuptura: r['tipo_ruptura']?.toString() ?? '',
                  porcentagem: (r['porcentagem'] as num?)?.toDouble() ?? 0,
                ))
            .toList();
        return LeituraArrancamentoBruta(
          nome: l['nome']?.toString() ?? '',
          imagemEnsaio: l['imagem_ensaio']?.toString(),
          imagemRuptura: l['imgem_ruptura']?.toString(),
          d1: (l['d1'] as num?)?.toDouble(),
          d2: (l['d2'] as num?)?.toDouble(),
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

      pontos.add(PontoArrancamentoBruto(
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
        tipoSubstrato: arr['tipo_substrato']?.toString() ?? '',
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

  // Soma as porcentagens de cada tipo de ruptura por TODAS as leituras
  // recebidas e retorna a de maior soma — mesma ideia de
  // `ElementoArrancamentoAgg.rupturaPredominante`.
  String _rupturaPredominante(List<LeituraArrancamentoBruta> leituras) {
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
  // recebidas — mesma normalização (divide pelo nº de leituras com ruptura
  // preenchida) do gráfico de pizza por ponto de
  // `analise_ponto_arrancamento_screen.dart` (`_gerarDadosPizza`), formatado
  // como `LeituraArrancamentoBruta.resumoRupturas` ("60% Argamassa | 40%
  // Substrato"), ordenado da maior pra menor porcentagem.
  String _rupturaAgrupada(List<LeituraArrancamentoBruta> leituras) {
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

  // Paleta por SIGLA — usa o catálogo canônico `CatalogoRupturas.itens`
  // (título -> sigla), não os mapeamentos de sigla legados e inconsistentes
  // das telas de análise (ver observação na pesquisa: o app tem várias
  // cópias divergentes desse mapeamento).
  static const Map<String, Color> _paletaRuptura = {
    'S': Color(0xFF795548),
    'S/A': Color(0xFFA1887F),
    'A': Color(0xFFFFB300),
    'F': Color(0xFFE53935),
    'S/C': Color(0xFF6D4C41),
    'C': Color(0xFF8D6E63),
    'C/A': Color(0xFFFFD54F),
  };

  Color _corRuptura(String tituloRuptura) {
    final item = CatalogoRupturas.itens.where((c) => c.titulo == tituloRuptura).firstOrNull;
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

  // Barra empilhada por leitura, segmentada proporcionalmente por tipo de
  // ruptura — igual à aba "Gráficos" de `analise_ponto_arrancamento_screen.dart`.
  Future<String> _graficoTensaoPorLeitura(PontoArrancamentoBruto p) async {
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

  Future<RegistroArrancamentoReal> _montarRegistroIndividual(PontoArrancamentoBruto p) async {
    final tensoes = p.tensoesValidas;
    final media = _media(tensoes);
    final cv = _cv(tensoes);
    final menor = tensoes.isEmpty ? 0.0 : tensoes.reduce(min);
    final maior = tensoes.isEmpty ? 0.0 : tensoes.reduce(max);
    final grafico = await _graficoTensaoPorLeitura(p);

    final leiturasDados = p.leituras
        .map((l) => <String, String>{
              'nome_leitura_arr': l.nome,
              if (l.imagemEnsaio != null && l.imagemEnsaio!.isNotEmpty) 'imagem_ensaio_leitura_arr': l.imagemEnsaio!,
              if (l.imagemRuptura != null && l.imagemRuptura!.isNotEmpty) 'imagem_ruptura_leitura_arr': l.imagemRuptura!,
              'd1_leitura_arr': l.d1 != null ? '${l.d1!.toStringAsFixed(1)} mm' : '-',
              'd2_leitura_arr': l.d2 != null ? '${l.d2!.toStringAsFixed(1)} mm' : '-',
              'diametro_medio_leitura_arr': '${l.diametroMedio.toStringAsFixed(1)} mm',
              'area_leitura_arr': '${l.areaCalculada.toStringAsFixed(1)} mm²',
              'carga_leitura_arr': l.carga != null ? '${l.carga!.toStringAsFixed(2)} KN' : '-',
              'tensao_leitura_arr': '${l.tensaoCalculada.toStringAsFixed(2)} MPa',
              'ruptura_leitura_arr': l.resumoRupturas,
            })
        .toList();

    return RegistroArrancamentoReal(
      dados: {
        'nome_elemento_arr': p.nomeElemento,
        'tipo_elemento_arr': p.tipoElemento,
        'local_elemento_arr': p.local,
        'revestimento_elemento_arr': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_arr': p.marcacaoImagemUrl!,
        'nome_ponto_arr': p.nomePonto,
        'valor_resultado_arr': p.valorResultado,
        if (p.imagemRegiao != null && p.imagemRegiao!.isNotEmpty) 'imagem_regiao_arr': p.imagemRegiao!,
        if (p.imagemColagem != null && p.imagemColagem!.isNotEmpty) 'imagem_colagem_arr': p.imagemColagem!,
        'temperatura_arr': p.temperatura,
        'umidade_arr': p.umidade,
        'idade_revestimento_arr': p.idadeRevestimento,
        'cola_utilizada_arr': p.colaUtilizada,
        'tipo_substrato_arr': p.tipoSubstrato,
        'media_tensao_arr': '${media.toStringAsFixed(2)} MPa',
        'maior_tensao_arr': '${maior.toStringAsFixed(2)} MPa',
        'menor_tensao_arr': '${menor.toStringAsFixed(2)} MPa',
        'cv_tensao_arr': '${cv.toStringAsFixed(1)}%',
        'ruptura_tipos_arr': _rupturaAgrupada(p.leituras),
        if (grafico.isNotEmpty) 'grafico_tensao_ruptura_arr': grafico,
      },
      leituras: leiturasDados,
      fotos: p.fotos,
    );
  }

  Future<List<RegistroArrancamentoReal>> montarRegistros(List<PontoArrancamentoBruto> pontos) async {
    final registros = <RegistroArrancamentoReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoArrancamentoBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoArrancamentoBruto>>{};
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
      final substratos = entrada.value.map((p) => p.tipoSubstrato).where((v) => v.isNotEmpty).toSet().join(', ');
      linhas.add({
        'local_grupo_arr': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_arr': rotulos[entrada.key]!.tipo,
        'temperatura_grupo_arr': temperaturas,
        'umidade_grupo_arr': umidades,
        'idade_revestimento_grupo_arr': idades,
        'cola_utilizada_grupo_arr': colas,
        'tipo_substrato_grupo_arr': substratos,
        'media_tensao_grupo_arr': '${_media(tensoes).toStringAsFixed(2)} MPa',
        'cv_tensao_grupo_arr': '${_cv(tensoes).toStringAsFixed(1)}%',
        'menor_tensao_grupo_arr': tensoes.isEmpty ? '-' : '${tensoes.reduce(min).toStringAsFixed(2)} MPa',
        'maior_tensao_grupo_arr': tensoes.isEmpty ? '-' : '${tensoes.reduce(max).toStringAsFixed(2)} MPa',
        'ruptura_predominante_grupo_arr': _rupturaPredominante(leiturasGrupo),
      });
    }
    return linhas;
  }

  // Agrupa por ELEMENTO INDIVIDUAL (local + nome do elemento), não pela
  // hierarquia escolhida — mesma chave de agrupamento de
  // `analise_todos_arrancamento_screen.dart` (`'${p.local}_${p.nomeElemento}'`).
  Map<String, List<PontoArrancamentoBruto>> _agruparPorElemento(List<PontoArrancamentoBruto> pontos) {
    final grupos = <String, List<PontoArrancamentoBruto>>{};
    for (final p in pontos) {
      grupos.putIfAbsent('${p.local}|${p.nomeElemento}', () => []).add(p);
    }
    return grupos;
  }

  // Barra de tensão média por elemento, segmentada por tipo de ruptura —
  // igual à aba "Gráficos" de `analise_todos_arrancamento_screen.dart`.
  Future<String> _graficoBarraTensaoElementos(List<PontoArrancamentoBruto> pontos) async {
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

  // Boxplot por LOCAL: pooled (todos os pontos do mesmo local numa caixa só)
  // — mesmo padrão genérico já usado por Carbonatação/Resistividade/Potencial.
  Future<String> _boxplotPorLocal(List<PontoArrancamentoBruto> pontos) async {
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

  // Boxplot por ELEMENTOS ESPECÍFICOS: uma caixa por elemento individual
  // (não pooled por tipo), colorida por tipo de elemento — igual à aba
  // "Estatísticas" de `analise_todos_arrancamento_screen.dart`.
  Future<String> _boxplotElementosEspecificos(List<PontoArrancamentoBruto> pontos) async {
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
    required List<PontoArrancamentoBruto> pontos,
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
    required List<PontoArrancamentoBruto> pontos,
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
