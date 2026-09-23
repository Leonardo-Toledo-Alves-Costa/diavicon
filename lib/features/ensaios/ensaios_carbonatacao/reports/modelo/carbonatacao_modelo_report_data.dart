import 'dart:math';

import 'package:flutter/material.dart' show Color, Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/carbonatacao_math.dart';
import '../../utils/curva_despassivacao.dart';

// Busca e calcula os dados reais de Carbonatação pro compositor de
// relatório. As fórmulas replicam, linha por linha, as já usadas em
// `analise_carbonatacao_provider.dart` (por ponto) e
// `reports/repositories/carbonatacao_report_service.dart` (agregado/Monte
// Carlo) — ver o plano em polymorphic-mixing-wind.md pra referência cruzada.
class RegistroCarbonatacaoReal {
  final Map<String, String> dados;
  final List<FotoRelatorio> fotos;
  const RegistroCarbonatacaoReal({required this.dados, required this.fotos});
}

class PontoCarbBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final double cobP;
  final double cobS;
  final double bitP;
  final double bitS;
  final List<double> frentes;
  final List<FotoRelatorio> fotos;

  const PontoCarbBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.cobP,
    required this.cobS,
    required this.bitP,
    required this.bitS,
    required this.frentes,
    required this.fotos,
  });
}

class CarbonatacaoModeloReportData {
  final SupabaseClient _supabase;
  CarbonatacaoModeloReportData(this._supabase);

  Future<int> buscarIdadeEstrutura(String estruturaId) async {
    try {
      final e = await _supabase.from('estruturas').select('ano_concepcao').eq('id', estruturaId).maybeSingle();
      final anoConcepcao = (e?['ano_concepcao'] as num?)?.toInt() ?? DateTime.now().year;
      return max(1, DateTime.now().year - anoConcepcao);
    } catch (_) {
      return 1;
    }
  }

  Future<List<PontoCarbBruto>> buscarPontosBrutos({required String projetoId, required String estruturaId}) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_carb(cob_arm_p, cob_arm_s, bit_arm_p, bit_arm_s,
            ponto_ensaio_carb_frentes(profundidade),
            galeria_ponto_ensaio_carb(imagem_url, referencia)),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('elementos_estruturais.estrutura_id', estruturaId);

    final pontos = <PontoCarbBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final carbBruto = p['ponto_ensaio_carb'];
      final carb = carbBruto is List && carbBruto.isNotEmpty
          ? (carbBruto.first as Map<String, dynamic>)
          : (carbBruto is Map ? carbBruto.cast<String, dynamic>() : null);
      if (carb == null) continue; // ponto sem dados de carbonatação preenchidos ainda

      final frentesResp = carb['ponto_ensaio_carb_frentes'] as List? ?? const [];
      final frentes = frentesResp.map((f) => ((f as Map)['profundidade'] as num).toDouble()).toList();

      final fotos = <FotoRelatorio>[];
      final galeriaCarb = carb['galeria_ponto_ensaio_carb'] as List? ?? const [];
      for (final g in galeriaCarb) {
        final url = g['imagem_url']?.toString();
        if (url == null || url.isEmpty) continue;
        final referencia = g['referencia']?.toString();
        final legenda = referencia == '1' ? 'Foto de quebra' : (referencia == '2' ? 'Foto de aspersão' : '');
        fotos.add(FotoRelatorio(url: url, descricao: legenda));
      }
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoCarbBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        cobP: (carb['cob_arm_p'] as num?)?.toDouble() ?? 0,
        cobS: (carb['cob_arm_s'] as num?)?.toDouble() ?? 0,
        bitP: (carb['bit_arm_p'] as num?)?.toDouble() ?? 0,
        bitS: (carb['bit_arm_s'] as num?)?.toDouble() ?? 0,
        frentes: frentes,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  // Fórmulas idênticas a `analise_carbonatacao_provider.dart:56-146` (a
  // análise de um único ponto) — inclusive o gráfico de avanço da frente
  // usa o mesmo fator (4 se tempoCalc<10, senão 2) daquela tela.
  Future<RegistroCarbonatacaoReal> _montarRegistroIndividual(PontoCarbBruto p, int idade) async {
    final cobrimentoEfetivo = (p.cobS > 0 && p.cobP > 0) ? min(p.cobS, p.cobP) : (p.cobS > 0 ? p.cobS : p.cobP);
    final mediaFrentes = CarbonatacaoMath.mean(p.frentes);
    final variancia =
        p.frentes.isEmpty ? 0.0 : p.frentes.map((x) => pow(x - mediaFrentes, 2)).reduce((a, b) => a + b) / p.frentes.length;
    final desvioPadrao = sqrt(variancia);
    final cv = mediaFrentes == 0 ? 0.0 : desvioPadrao / mediaFrentes * 100;
    final coefCarb = mediaFrentes / sqrt(idade);
    final tempoCarbonatar = coefCarb > 0 ? pow(cobrimentoEfetivo / coefCarb, 2).toDouble() : 999.0;
    final deltaCarb = tempoCarbonatar - idade;
    final tempoCalc = deltaCarb <= 0 ? idade.toDouble() : tempoCarbonatar;
    final fator = tempoCalc < 10 ? 4 : 2;
    final tempoAnalise = tempoCalc * fator;

    const passos = 60;
    final pontosFrente = <PontoGrafico>[];
    final pontosCob = <PontoGrafico>[];
    for (var i = 0; i <= passos; i++) {
      final t = tempoAnalise * i / passos;
      pontosFrente.add(PontoGrafico(t, coefCarb * sqrt(t)));
      pontosCob.add(PontoGrafico(t, cobrimentoEfetivo));
    }
    final grafico = await RelatorioChartRenderer.linhaComFaixa(
      series: [
        SerieLinha(nome: 'Cobrimento (mm)', pontos: pontosCob, cor: const Color(0xFFC896FF), preenchida: true),
        SerieLinha(nome: 'Frente de carbonatação (mm)', pontos: pontosFrente, cor: const Color(0xFF616161), preenchida: true),
      ],
      marcadores: [
        MarcadorVertical(x: idade.toDouble(), rotulo: 'Idade', cor: Colors.orange),
        MarcadorVertical(x: tempoCarbonatar.clamp(0, tempoAnalise).toDouble(), rotulo: 'Falha', cor: Colors.red),
      ],
      tituloEixoX: 'Exposição (anos)',
      tituloEixoY: 'Profundidade (mm)',
    );

    return RegistroCarbonatacaoReal(
      dados: {
        'nome_elemento_carb': p.nomeElemento,
        'tipo_elemento_carb': p.tipoElemento,
        'local_elemento_carb': p.local,
        'revestimento_elemento_carb': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_carb': p.marcacaoImagemUrl!,
        'nome_ponto_carb': p.nomePonto,
        'valor_resultado_carb': p.valorResultado,
        'cob_arm_p_carb': p.cobP > 0 ? '${p.cobP.toStringAsFixed(1)} mm' : '-',
        'cob_arm_s_carb': p.cobS > 0 ? '${p.cobS.toStringAsFixed(1)} mm' : '-',
        'bit_arm_p_carb': p.bitP > 0 ? '${p.bitP.toStringAsFixed(1)} mm' : '-',
        'bit_arm_s_carb': p.bitS > 0 ? '${p.bitS.toStringAsFixed(1)} mm' : '-',
        'media_frente_carb': '${mediaFrentes.toStringAsFixed(1)} mm',
        'desvio_padrao_frente_carb': '${desvioPadrao.toStringAsFixed(2)} mm',
        'cv_frente_carb': '${cv.toStringAsFixed(1)}%',
        'coef_carbonatacao_carb': coefCarb.toStringAsFixed(2),
        'tempo_despassivacao_carb': '${tempoCarbonatar.toStringAsFixed(0)} anos',
        'grafico_avanco_frente_carb': grafico,
      },
      fotos: p.fotos,
    );
  }

  // `pontos`/`idade` já vêm buscados pelo chamador (ver
  // CarbonatacaoModeloReportService) porque são reaproveitados também pelas
  // seções de Referencial e Registros Agrupados — evita buscar tudo de novo
  // pra cada seção do relatório.
  Future<List<RegistroCarbonatacaoReal>> montarRegistros(List<PontoCarbBruto> pontos, int idade) async {
    final registros = <RegistroCarbonatacaoReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p, idade));
    }
    return registros;
  }

  // "Condições do local"/"Tipologia do local"/"Tipologias de elemento"/
  // "Revestimento de elemento" (ver EnsaioModeloConfig.catalogosReferencialPermitidos
  // — só Estrutura + Tipologia/Revestimento de elemento fazem sentido pra
  // Carbonatação) casam por TEXTO com o catálogo, igual ao mesmo mecanismo
  // já usado pela Inspeção Visual (`InspecaoVisualReportData._buscarCatalogoPorNome`).
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
    required List<PontoCarbBruto> pontos,
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

  // Uma linha por grupo (Local, Tipo de elemento, ou os dois — ver
  // `HierarquiaAgrupamento`) com as mesmas fórmulas agregadas de
  // `carbonatacao_report_service.dart:222-293` (médias/desvios/CV, Monte
  // Carlo de probabilidade de despassivação).
  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoCarbBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
    required int idade,
  }) async {
    final grupos = <String, List<PontoCarbBruto>>{};
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
      linhas.add(_calcularLinhaGrupo(rotulos[entrada.key]!, entrada.value, idade));
    }
    return linhas;
  }

  Map<String, String> _calcularLinhaGrupo(({String local, String tipo}) rotulo, List<PontoCarbBruto> pontosDoGrupo, int idade) {
    final cobPList = pontosDoGrupo.map((p) => p.cobP).where((v) => v > 0).toList();
    final cobSList = pontosDoGrupo.map((p) => p.cobS).where((v) => v > 0).toList();
    final frentes = pontosDoGrupo.expand((p) => p.frentes).toList();

    final mediaCobP = CarbonatacaoMath.mean(cobPList);
    final dpCobP = CarbonatacaoMath.stdDev(cobPList);
    final cvCobP = mediaCobP == 0 ? 0.0 : dpCobP / mediaCobP * 100;

    final mediaCobS = CarbonatacaoMath.mean(cobSList);
    final dpCobS = CarbonatacaoMath.stdDev(cobSList);
    final cvCobS = mediaCobS == 0 ? 0.0 : dpCobS / mediaCobS * 100;

    final mediaFrente = CarbonatacaoMath.mean(frentes);
    final dpFrente = CarbonatacaoMath.stdDev(frentes);
    final cvFrente = mediaFrente == 0 ? 0.0 : dpFrente / mediaFrente * 100;

    // Mesma lógica (com a mesma peculiaridade) de
    // `carbonatacao_report_service.dart:236-237`: usa o menor dos dois
    // cobrimentos médios — se um dos dois grupos não tiver medição
    // nenhuma, a média dele é 0 e "vence" como menor, então mantemos o
    // comportamento já em produção em vez de divergir do gerador existente.
    final mediaCob = min(mediaCobP, mediaCobS);
    final dpCob = mediaCobS <= mediaCobP ? dpCobS : dpCobP;

    final kMedia = idade > 0 ? mediaFrente / sqrt(idade) : 0.0;
    final tempoTotal = kMedia > 0 ? pow(mediaCob / kMedia, 2).toDouble() : 999.0;
    var vidaUtilResidual = tempoTotal - idade;
    if (vidaUtilResidual < 0) vidaUtilResidual = 0;

    String risco;
    if (vidaUtilResidual == 0) {
      risco = 'Despassivado';
    } else if (vidaUtilResidual < 5) {
      risco = 'Risco Alto';
    } else if (vidaUtilResidual < 15) {
      risco = 'Risco Moderado';
    } else if (vidaUtilResidual < 30) {
      risco = 'Risco Baixo';
    } else {
      risco = 'Risco Irrelevante';
    }

    final arrayK = frentes.map((f) => f / sqrt(idade)).toList();
    final kMd = CarbonatacaoMath.mean(arrayK);
    final kDp = CarbonatacaoMath.stdDev(arrayK);
    final tempoCalc = vidaUtilResidual == 0 ? idade.toDouble() : tempoTotal;
    final tempoAnalisePb = tempoCalc * (tempoCalc < 10 ? 3 : 2);
    // Monte Carlo: fonte única (CurvaDespassivacao), com semente fixa por grupo.
    final curva = CurvaDespassivacao.calcular(
      kMedia: kMd, kDesvio: kDp, cobMedia: mediaCob, cobDesvio: dpCob,
      horizonte: tempoAnalisePb, chave: 'carbonatacao|linha|${rotulo.local}|${rotulo.tipo}',
    );
    final tLabels = curva.tempos;
    final probValues = curva.probabilidades;
    String buscarTempoProb(double alvo) {
      for (var i = 0; i < probValues.length; i++) {
        if (probValues[i] >= alvo) return '${tLabels[i].toStringAsFixed(1)} anos';
      }
      return '> ${tempoAnalisePb.toStringAsFixed(0)} anos';
    }

    return {
      'local_grupo_carb': rotulo.local,
      'tipo_elemento_grupo_carb': rotulo.tipo,
      'media_cob_p_grupo_carb': '${mediaCobP.toStringAsFixed(1)} mm',
      'cv_cob_p_grupo_carb': '${cvCobP.toStringAsFixed(1)}%',
      'dp_cob_p_grupo_carb': '${dpCobP.toStringAsFixed(2)} mm',
      'media_cob_s_grupo_carb': '${mediaCobS.toStringAsFixed(1)} mm',
      'cv_cob_s_grupo_carb': '${cvCobS.toStringAsFixed(1)}%',
      'dp_cob_s_grupo_carb': '${dpCobS.toStringAsFixed(2)} mm',
      'media_frente_grupo_carb': '${mediaFrente.toStringAsFixed(1)} mm',
      'cv_frente_grupo_carb': '${cvFrente.toStringAsFixed(1)}%',
      'dp_frente_grupo_carb': '${dpFrente.toStringAsFixed(2)} mm',
      'coef_carbonatacao_grupo_carb': kMedia.toStringAsFixed(2),
      'tempo_despassivacao_grupo_carb': '${tempoTotal.toStringAsFixed(0)} anos',
      'risco_grupo_carb': risco,
      'prob_20_grupo_carb': buscarTempoProb(20),
      'prob_40_grupo_carb': buscarTempoProb(40),
      'prob_60_grupo_carb': buscarTempoProb(60),
      'prob_80_grupo_carb': buscarTempoProb(80),
    };
  }

  // Gráficos-resumo da seção "Registros agrupados" (ver `graficosResumoDisponiveis`)
  // — avanço da frente e probabilidade são globais (pooling de todos os
  // pontos); os boxplots comparam os grupos entre si. Fórmulas idênticas a
  // `carbonatacao_report_service.dart:317-476`.
  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoCarbBruto> pontos,
    required int idade,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    final todasFrentes = pontos.expand((p) => p.frentes).toList();
    final todosCobP = pontos.map((p) => p.cobP).where((v) => v > 0).toList();
    final todosCobS = pontos.map((p) => p.cobS).where((v) => v > 0).toList();
    final mediaCob = min(CarbonatacaoMath.mean(todosCobP), CarbonatacaoMath.mean(todosCobS));
    final dpCob = CarbonatacaoMath.mean(todosCobS) <= CarbonatacaoMath.mean(todosCobP)
        ? CarbonatacaoMath.stdDev(todosCobS)
        : CarbonatacaoMath.stdDev(todosCobP);
    final mediaFrente = CarbonatacaoMath.mean(todasFrentes);
    final kMedia = idade > 0 ? mediaFrente / sqrt(idade) : 0.0;
    final tempoTotal = kMedia > 0 ? pow(mediaCob / kMedia, 2).toDouble() : 999.0;

    if (graficosSelecionados.contains(chaveGraficoAvancoFrente)) {
      final tempoAnaliseG1 = max(idade * 2, tempoTotal * 2);
      final pontosCob = <PontoGrafico>[];
      final pontosFrente = <PontoGrafico>[];
      const passos = 50;
      for (var i = 0; i <= passos; i++) {
        final t = tempoAnaliseG1 * i / passos;
        pontosCob.add(PontoGrafico(t, mediaCob));
        pontosFrente.add(PontoGrafico(t, sqrt(t) * kMedia));
      }
      resultado[chaveGraficoAvancoFrente] = await RelatorioChartRenderer.linhaComFaixa(
        series: [
          SerieLinha(nome: 'Cobrimento (mm)', pontos: pontosCob, cor: const Color(0xFFC896FF), preenchida: true),
          SerieLinha(nome: 'Frente de carbonatação (mm)', pontos: pontosFrente, cor: const Color(0xFF616161), preenchida: true),
        ],
        marcadores: [
          MarcadorVertical(x: idade.toDouble(), rotulo: 'Idade', cor: Colors.orange),
          MarcadorVertical(x: tempoTotal.clamp(0, tempoAnaliseG1).toDouble(), rotulo: 'Falha', cor: Colors.red),
        ],
        tituloEixoX: 'Exposição (anos)',
        tituloEixoY: 'Profundidade (mm)',
      );
    }

    if (graficosSelecionados.contains(chaveGraficoProbabilidade)) {
      var vidaUtilResidual = tempoTotal - idade;
      if (vidaUtilResidual < 0) vidaUtilResidual = 0;
      final tempoCalc = vidaUtilResidual == 0 ? idade.toDouble() : tempoTotal;
      final tempoAnalisePb = tempoCalc * (tempoCalc < 10 ? 3 : 2);
      final arrayK = todasFrentes.map((f) => f / sqrt(idade)).toList();
      final kMd = CarbonatacaoMath.mean(arrayK);
      final kDp = CarbonatacaoMath.stdDev(arrayK);
      // Mesma chave do dashboard (chaveGeral): com as mesmas entradas, o PDF
      // e o dashboard mostram exatamente a mesma curva.
      final curva = CurvaDespassivacao.calcular(
        kMedia: kMd, kDesvio: kDp, cobMedia: mediaCob, cobDesvio: dpCob,
        horizonte: tempoAnalisePb, chave: CurvaDespassivacao.chaveGeral,
      );
      final pontosProb = [
        for (var i = 0; i < curva.tempos.length; i++) PontoGrafico(curva.tempos[i], curva.probabilidades[i]),
      ];
      resultado[chaveGraficoProbabilidade] = await RelatorioChartRenderer.linhaComFaixa(
        series: [SerieLinha(nome: 'Probabilidade de despassivação (%)', pontos: pontosProb, cor: Colors.red, preenchida: true)],
        marcadores: [MarcadorVertical(x: idade.toDouble(), rotulo: 'Idade', cor: Colors.orange)],
        tituloEixoX: 'Exposição (anos)',
        tituloEixoY: 'Probabilidade (%)',
      );
    }

    if (graficosSelecionados.contains(chaveGraficoAvancoFrentePorElemento)) {
      resultado[chaveGraficoAvancoFrentePorElemento] = await _avancoFrentePor(pontos, (p) => p.tipoElemento, idade);
    }
    if (graficosSelecionados.contains(chaveGraficoAvancoFrentePorLocal)) {
      resultado[chaveGraficoAvancoFrentePorLocal] = await _avancoFrentePor(pontos, (p) => p.local, idade);
    }
    if (graficosSelecionados.contains(chaveGraficoProbabilidadePorElemento)) {
      resultado[chaveGraficoProbabilidadePorElemento] = await _probabilidadePor(pontos, (p) => p.tipoElemento, idade);
    }
    if (graficosSelecionados.contains(chaveGraficoProbabilidadePorLocal)) {
      resultado[chaveGraficoProbabilidadePorLocal] = await _probabilidadePor(pontos, (p) => p.local, idade);
    }

    if (graficosSelecionados.contains(chaveGraficoBoxplotElemento)) {
      resultado[chaveGraficoBoxplotElemento] = await _boxplotPor(pontos, (p) => p.tipoElemento);
    }
    if (graficosSelecionados.contains(chaveGraficoBoxplotLocal)) {
      resultado[chaveGraficoBoxplotLocal] = await _boxplotPor(pontos, (p) => p.local);
    }

    return resultado;
  }

  // Paleta cíclica pra diferenciar visualmente cada grupo (elemento/local)
  // nos gráficos multi-série "por elemento"/"por local".
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

  // Mesma curva "y = √t · k" do gráfico global, só que uma série por grupo
  // (Tipo de elemento ou Local) em vez de uma curva só com todos os pontos
  // agrupados — usa um eixo X comum (o maior "tempoTotal" entre os grupos)
  // pra todas as curvas caberem no mesmo gráfico.
  Future<String> _avancoFrentePor(List<PontoCarbBruto> pontos, String Function(PontoCarbBruto) chaveDe, int idade) async {
    final grupos = <String, List<PontoCarbBruto>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).add(p);
    }
    if (grupos.isEmpty) return '';

    final kMediaPorGrupo = <String, double>{};
    final tempoTotalPorGrupo = <String, double>{};
    for (final entrada in grupos.entries) {
      final frentes = entrada.value.expand((p) => p.frentes).toList();
      final cobP = entrada.value.map((p) => p.cobP).where((v) => v > 0).toList();
      final cobS = entrada.value.map((p) => p.cobS).where((v) => v > 0).toList();
      final mediaCobGrupo = min(CarbonatacaoMath.mean(cobP), CarbonatacaoMath.mean(cobS));
      final mediaFrenteGrupo = CarbonatacaoMath.mean(frentes);
      final kMediaGrupo = idade > 0 ? mediaFrenteGrupo / sqrt(idade) : 0.0;
      kMediaPorGrupo[entrada.key] = kMediaGrupo;
      tempoTotalPorGrupo[entrada.key] = kMediaGrupo > 0 ? pow(mediaCobGrupo / kMediaGrupo, 2).toDouble() : 999.0;
    }

    final maiorTempoTotal = tempoTotalPorGrupo.values.reduce((a, b) => a > b ? a : b);
    final tempoAnaliseG1 = max(idade * 2, maiorTempoTotal * 2);

    final series = <SerieLinha>[];
    var i = 0;
    for (final chave in grupos.keys) {
      final kMediaGrupo = kMediaPorGrupo[chave]!;
      final pontosFrente = <PontoGrafico>[];
      const passos = 50;
      for (var p = 0; p <= passos; p++) {
        final t = tempoAnaliseG1 * p / passos;
        pontosFrente.add(PontoGrafico(t, sqrt(t) * kMediaGrupo));
      }
      series.add(SerieLinha(nome: chave, pontos: pontosFrente, cor: _paletaGrupos[i % _paletaGrupos.length]));
      i++;
    }

    return RelatorioChartRenderer.linhaComFaixa(
      series: series,
      marcadores: [MarcadorVertical(x: idade.toDouble(), rotulo: 'Idade', cor: Colors.orange)],
      tituloEixoX: 'Exposição (anos)',
      tituloEixoY: 'Frente de carbonatação (mm)',
    );
  }

  // Mesma simulação de Monte Carlo do gráfico global de probabilidade, só
  // que uma curva por grupo (Tipo de elemento ou Local).
  Future<String> _probabilidadePor(List<PontoCarbBruto> pontos, String Function(PontoCarbBruto) chaveDe, int idade) async {
    final grupos = <String, List<PontoCarbBruto>>{};
    for (final p in pontos) {
      grupos.putIfAbsent(chaveDe(p), () => []).add(p);
    }
    if (grupos.isEmpty) return '';

    final kMdPorGrupo = <String, double>{};
    final kDpPorGrupo = <String, double>{};
    final mediaCobPorGrupo = <String, double>{};
    final dpCobPorGrupo = <String, double>{};
    final tempoAnalisePbPorGrupo = <String, double>{};

    for (final entrada in grupos.entries) {
      final frentes = entrada.value.expand((p) => p.frentes).toList();
      final cobP = entrada.value.map((p) => p.cobP).where((v) => v > 0).toList();
      final cobS = entrada.value.map((p) => p.cobS).where((v) => v > 0).toList();
      final mediaCobGrupo = min(CarbonatacaoMath.mean(cobP), CarbonatacaoMath.mean(cobS));
      final dpCobGrupo = CarbonatacaoMath.mean(cobS) <= CarbonatacaoMath.mean(cobP)
          ? CarbonatacaoMath.stdDev(cobS)
          : CarbonatacaoMath.stdDev(cobP);
      final mediaFrenteGrupo = CarbonatacaoMath.mean(frentes);
      final kMediaGrupo = idade > 0 ? mediaFrenteGrupo / sqrt(idade) : 0.0;
      final tempoTotalGrupo = kMediaGrupo > 0 ? pow(mediaCobGrupo / kMediaGrupo, 2).toDouble() : 999.0;
      var vidaUtilResidualGrupo = tempoTotalGrupo - idade;
      if (vidaUtilResidualGrupo < 0) vidaUtilResidualGrupo = 0;
      final tempoCalcGrupo = vidaUtilResidualGrupo == 0 ? idade.toDouble() : tempoTotalGrupo;
      final arrayK = frentes.map((f) => f / sqrt(idade)).toList();

      kMdPorGrupo[entrada.key] = CarbonatacaoMath.mean(arrayK);
      kDpPorGrupo[entrada.key] = CarbonatacaoMath.stdDev(arrayK);
      mediaCobPorGrupo[entrada.key] = mediaCobGrupo;
      dpCobPorGrupo[entrada.key] = dpCobGrupo;
      tempoAnalisePbPorGrupo[entrada.key] = tempoCalcGrupo * (tempoCalcGrupo < 10 ? 3 : 2);
    }

    final maiorTempoAnalisePb = tempoAnalisePbPorGrupo.values.reduce((a, b) => a > b ? a : b);

    final series = <SerieLinha>[];
    var i = 0;
    for (final chave in grupos.keys) {
      final curva = CurvaDespassivacao.calcular(
        kMedia: kMdPorGrupo[chave]!, kDesvio: kDpPorGrupo[chave]!,
        cobMedia: mediaCobPorGrupo[chave]!, cobDesvio: dpCobPorGrupo[chave]!,
        horizonte: maiorTempoAnalisePb, chave: 'carbonatacao|grupo|$chave',
      );
      final pontosProb = [
        for (var j = 0; j < curva.tempos.length; j++) PontoGrafico(curva.tempos[j], curva.probabilidades[j]),
      ];
      series.add(SerieLinha(nome: chave, pontos: pontosProb, cor: _paletaGrupos[i % _paletaGrupos.length]));
      i++;
    }

    return RelatorioChartRenderer.linhaComFaixa(
      series: series,
      marcadores: [MarcadorVertical(x: idade.toDouble(), rotulo: 'Idade', cor: Colors.orange)],
      tituloEixoX: 'Exposição (anos)',
      tituloEixoY: 'Probabilidade (%)',
    );
  }

  Future<String> _boxplotPor(List<PontoCarbBruto> pontos, String Function(PontoCarbBruto) chaveDe) async {
    final cobPorGrupo = <String, List<double>>{};
    final frentePorGrupo = <String, List<double>>{};
    for (final p in pontos) {
      final chave = chaveDe(p);
      final cobs = <double>[if (p.cobP > 0) p.cobP, if (p.cobS > 0) p.cobS];
      cobPorGrupo.putIfAbsent(chave, () => []).addAll(cobs);
      frentePorGrupo.putIfAbsent(chave, () => []).addAll(p.frentes);
    }

    final rotulos = cobPorGrupo.keys.toList();
    GrupoBoxplot montarGrupo(String rotulo, List<double> valores) {
      if (valores.isEmpty) return GrupoBoxplot(rotulo: rotulo, minimo: 0, media: 0, maximo: 0);
      return GrupoBoxplot(
        rotulo: rotulo,
        minimo: valores.reduce(min),
        media: CarbonatacaoMath.mean(valores),
        maximo: valores.reduce(max),
      );
    }

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Cobrimento (mm)',
          cor: const Color(0xFFC896FF),
          grupos: [for (final r in rotulos) montarGrupo(r, cobPorGrupo[r] ?? const [])],
        ),
        SerieBoxplot(
          nome: 'Carbonatação (mm)',
          cor: const Color(0xFF757575),
          grupos: [for (final r in rotulos) montarGrupo(r, frentePorGrupo[r] ?? const [])],
        ),
      ],
      tituloEixoY: 'Profundidade (mm)',
    );
  }
}
