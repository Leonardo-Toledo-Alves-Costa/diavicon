import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/html/quadro_html_helpers.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';

// Busca e calcula os dados reais de Prova de Carga Estática pro compositor
// de relatório. Fórmulas replicadas de `analise_prova_carga_utils.dart`
// (`calcularEstatisticasPonto`/`formatarDuracao` — única fonte, usada tanto
// na coleta quanto na análise) e do gráfico de
// `analise_prova_carga_screen.dart` (`_buildAbaGraficos`). Diferente dos
// demais ensaios: elemento estrutural é OPCIONAL, então o embed de
// `elementos_estruturais` NÃO usa `!inner` e o filtro por estrutura é feito
// direto em `pontos_ensaios_geral.estrutura_id` (coluna própria, sempre
// preenchida na criação — ver `ProvaCargaRepository.criarAreaInicial`).
class RegistroProvaCargaReal {
  final Map<String, String> dados;
  final List<Map<String, String>> pontosMedicao;
  final List<FotoRelatorio> fotos;
  const RegistroProvaCargaReal({required this.dados, required this.pontosMedicao, required this.fotos});
}

class LeituraProvaCargaBruta {
  final int deslocamento;
  final int carregamento;
  final String etapa; // 'Carregamento' | 'Descarregamento'
  final String horario; // 'HH:mm'
  const LeituraProvaCargaBruta({required this.deslocamento, required this.carregamento, required this.etapa, required this.horario});
}

class PontoMedicaoBruto {
  final String nome;
  final int? deslocMax;
  final String? descricao;
  final String? tipoElemento;
  final List<LeituraProvaCargaBruta> leituras;
  const PontoMedicaoBruto({required this.nome, required this.deslocMax, required this.descricao, required this.tipoElemento, required this.leituras});
}

class PontoProvaCargaBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final String valorResultado;
  final int cargaTotal;
  final int carregamento;
  final int etapaCarregamento;
  final int etapaDescarregamento;
  final String? plantaFoto;
  final List<PontoMedicaoBruto> pontosMedicao;
  final List<FotoRelatorio> fotos;

  const PontoProvaCargaBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.valorResultado,
    required this.cargaTotal,
    required this.carregamento,
    required this.etapaCarregamento,
    required this.etapaDescarregamento,
    required this.plantaFoto,
    required this.pontosMedicao,
    required this.fotos,
  });
}

class ProvaCargaModeloReportData {
  final SupabaseClient _supabase;
  ProvaCargaModeloReportData(this._supabase);

  Future<List<PontoProvaCargaBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase.from('pontos_ensaios_geral').select('''
          id, nome_ponto, valor_resultado,
          elementos_estruturais(nome, tipo, local, revestimento, marcacao_imagem_url),
          ponto_ensaio_prova_carga(carga_total, carregamento, etapa_carregamento, etapa_descarregamento, planta_foto,
            ponto_ensaio_prova_carga_ponto_medicao(nome, desloc_max, descricao, tipo_elemento,
              ponto_ensaio_prova_carga_ponto_leitura(deslocamento, carregamento, etapa, horario))),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''').eq('projeto_id', projetoId).eq('estrutura_id', estruturaId).eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoProvaCargaBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final areaBruta = p['ponto_ensaio_prova_carga'];
      final area = areaBruta is List && areaBruta.isNotEmpty
          ? (areaBruta.first as Map<String, dynamic>)
          : (areaBruta is Map ? areaBruta.cast<String, dynamic>() : null);
      if (area == null) continue; // ponto sem área de ensaio preenchida ainda

      final medicoesResp = area['ponto_ensaio_prova_carga_ponto_medicao'] as List? ?? const [];
      final pontosMedicao = medicoesResp.map((m) {
        final leiturasResp = m['ponto_ensaio_prova_carga_ponto_leitura'] as List? ?? const [];
        final leituras = leiturasResp.map((l) {
          var horario = l['horario']?.toString() ?? '00:00';
          if (horario.length >= 5) horario = horario.substring(0, 5);
          return LeituraProvaCargaBruta(
            deslocamento: (l['deslocamento'] as num?)?.toInt() ?? 0,
            carregamento: (l['carregamento'] as num?)?.toInt() ?? 0,
            etapa: l['etapa']?.toString() ?? 'Carregamento',
            horario: horario,
          );
        }).toList();
        return PontoMedicaoBruto(
          nome: m['nome']?.toString() ?? '',
          deslocMax: (m['desloc_max'] as num?)?.toInt(),
          descricao: m['descricao']?.toString(),
          tipoElemento: m['tipo_elemento']?.toString(),
          leituras: leituras,
        );
      }).toList();

      final fotos = <FotoRelatorio>[];
      final galeriaGeral = p['galeria_pontos_ensaios_geral'] as List? ?? const [];
      for (final g in galeriaGeral) {
        final url = g['imagem_url']?.toString();
        if (url != null && url.isNotEmpty) fotos.add(FotoRelatorio(url: url, descricao: g['legenda']?.toString() ?? ''));
      }

      pontos.add(PontoProvaCargaBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        valorResultado: p['valor_resultado']?.toString() ?? '',
        cargaTotal: (area['carga_total'] as num?)?.toInt() ?? 0,
        carregamento: (area['carregamento'] as num?)?.toInt() ?? 0,
        etapaCarregamento: (area['etapa_carregamento'] as num?)?.toInt() ?? 0,
        etapaDescarregamento: (area['etapa_descarregamento'] as num?)?.toInt() ?? 0,
        plantaFoto: area['planta_foto']?.toString(),
        pontosMedicao: pontosMedicao,
        fotos: fotos,
      ));
    }
    return pontos;
  }

  DateTime _parseHorario(String horario) {
    final partes = horario.split(':');
    if (partes.length < 2) return DateTime(2000, 1, 1);
    return DateTime(2000, 1, 1, int.tryParse(partes[0]) ?? 0, int.tryParse(partes[1]) ?? 0);
  }

  String _condicao(int? deslocMax, int deslocamentoMaximo) {
    if (deslocMax == null) return '-';
    return deslocamentoMaximo > deslocMax ? 'Excedido' : 'Dentro do limite';
  }

  String _formatarDuracao(Duration? d) {
    if (d == null) return '-';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}min';
    return '${h}h${m.toString().padLeft(2, '0')}min';
  }

  // Réplica exata de `calcularEstatisticasPonto` (analise_prova_carga_utils.dart):
  // residual = maior deslocamento do carregamento - deslocamento da última
  // leitura do descarregamento (menor carga = fim do descarregamento).
  ({int deslocamentoMaximo, int? residual, Duration? duracao}) _estatisticasMedicao(PontoMedicaoBruto ponto) {
    final leituras = ponto.leituras;
    final leiturasCarregamento = leituras.where((l) => l.etapa == 'Carregamento').toList()
      ..sort((a, b) => a.carregamento.compareTo(b.carregamento));
    final leiturasDescarregamento = leituras.where((l) => l.etapa == 'Descarregamento').toList()
      ..sort((a, b) => b.carregamento.compareTo(a.carregamento));

    final deslocamentoMaximo = leituras.isEmpty ? 0 : leituras.map((l) => l.deslocamento).reduce((a, b) => a > b ? a : b);

    int? residual;
    if (leiturasCarregamento.isNotEmpty && leiturasDescarregamento.isNotEmpty) {
      final maxCarregamentoDesloc = leiturasCarregamento.map((l) => l.deslocamento).reduce((a, b) => a > b ? a : b);
      final deslocFinalDescarregamento = leiturasDescarregamento.last.deslocamento;
      residual = maxCarregamentoDesloc - deslocFinalDescarregamento;
    }

    Duration? duracao;
    if (leituras.length >= 2) {
      final horarios = leituras.map((l) => _parseHorario(l.horario)).toList()..sort();
      duracao = horarios.last.difference(horarios.first);
    }

    return (deslocamentoMaximo: deslocamentoMaximo, residual: residual, duracao: duracao);
  }

  // Curva de deslocamento x carga — igual à aba "Gráficos" de
  // `analise_prova_carga_screen.dart`: carregamento em laranja (cor
  // idêntica), descarregamento em azul-marinho conectando a partir do
  // último ponto do carregamento, eixo Y invertido (deslocamento cresce
  // pra baixo, mesma convenção de `NumericAxis(isInversed: true)`).
  Future<String> _graficoDeslocamentoCarga(PontoMedicaoBruto ponto) async {
    final leiturasCarregamento = ponto.leituras.where((l) => l.etapa == 'Carregamento').toList()
      ..sort((a, b) => a.carregamento.compareTo(b.carregamento));
    final leiturasDescarregamento = ponto.leituras.where((l) => l.etapa == 'Descarregamento').toList()
      ..sort((a, b) => b.carregamento.compareTo(a.carregamento));
    if (leiturasCarregamento.isEmpty && leiturasDescarregamento.isEmpty) return '';

    final pontosCarregamento = leiturasCarregamento.map((l) => PontoGrafico(l.carregamento.toDouble(), l.deslocamento.toDouble())).toList();
    final leiturasDescarregamentoCompleto = [
      if (leiturasCarregamento.isNotEmpty) leiturasCarregamento.last,
      ...leiturasDescarregamento,
    ];
    final pontosDescarregamento =
        leiturasDescarregamentoCompleto.map((l) => PontoGrafico(l.carregamento.toDouble(), l.deslocamento.toDouble())).toList();

    return RelatorioChartRenderer.linhaComFaixa(
      series: [
        if (pontosCarregamento.isNotEmpty) SerieLinha(nome: 'Carregamento', pontos: pontosCarregamento, cor: const Color(0xFFFFA726)),
        if (pontosDescarregamento.isNotEmpty) SerieLinha(nome: 'Descarregamento', pontos: pontosDescarregamento, cor: const Color(0xFF1B2A4A)),
      ],
      tituloEixoX: 'Carga (kg)',
      tituloEixoY: 'Deslocamento (mm)',
      inverterEixoY: true,
    );
  }

  // Tabela HTML das leituras de um ponto de medição (Desloc./Carga/Etapa/
  // Hora) — mesma ordenação (etapa, depois carga) e mesmas cores de etapa de
  // `analise_prova_carga_screen.dart` (`_buildAbaTabelas`).
  String _tabelaLeiturasHtml(PontoMedicaoBruto ponto) {
    if (ponto.leituras.isEmpty) return '';
    final leituras = [...ponto.leituras]..sort((a, b) {
        final etapaCompare = a.etapa.compareTo(b.etapa);
        return etapaCompare != 0 ? etapaCompare : a.carregamento.compareTo(b.carregamento);
      });

    final buffer = StringBuffer('<table class="resumo"><thead><tr><th>Desloc.</th><th>Carga</th><th>Etapa</th><th>Hora</th></tr></thead><tbody>');
    for (final l in leituras) {
      final corEtapa = l.etapa == 'Carregamento' ? '#FFA726' : '#1B2A4A';
      buffer.write(
          '<tr><td>${l.deslocamento} mm</td><td>${l.carregamento} kg</td><td style="color:$corEtapa;font-weight:bold;">${QuadroHtmlHelpers.escapar(l.etapa)}</td><td>${QuadroHtmlHelpers.escapar(l.horario)}</td></tr>');
    }
    buffer.write('</tbody></table>');
    return buffer.toString();
  }

  Future<RegistroProvaCargaReal> _montarRegistroIndividual(PontoProvaCargaBruto p) async {
    final pontosMedicaoDados = <Map<String, String>>[];
    for (final medicao in p.pontosMedicao) {
      final stats = _estatisticasMedicao(medicao);
      final grafico = await _graficoDeslocamentoCarga(medicao);
      final tabela = _tabelaLeiturasHtml(medicao);
      pontosMedicaoDados.add({
        'nome_ponto_medicao_pc': medicao.nome,
        if (medicao.deslocMax != null) 'desloc_max_pc': '${medicao.deslocMax} mm',
        'descricao_pc': medicao.descricao ?? '',
        'tipo_elemento_medicao_pc': medicao.tipoElemento ?? '',
        if (grafico.isNotEmpty) 'grafico_deslocamento_carga_pc': grafico,
        'condicao_pc': _condicao(medicao.deslocMax, stats.deslocamentoMaximo),
        'residual_maximo_pc': stats.residual != null ? '${stats.residual} mm' : '-',
        'duracao_total_pc': _formatarDuracao(stats.duracao),
        if (tabela.isNotEmpty) 'tabela_leituras_pc': tabela,
      });
    }

    return RegistroProvaCargaReal(
      dados: {
        'nome_elemento_pc': p.nomeElemento,
        'tipo_elemento_pc': p.tipoElemento,
        'local_elemento_pc': p.local,
        'revestimento_elemento_pc': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_pc': p.marcacaoImagemUrl!,
        'nome_ponto_pc': p.nomePonto,
        'valor_resultado_pc': p.valorResultado,
        'carga_total_pc': '${p.cargaTotal} kg',
        'carregamento_pc': '${p.carregamento} kg/m²',
        'etapa_carregamento_pc': '${p.etapaCarregamento} etapas',
        'etapa_descarregamento_pc': '${p.etapaDescarregamento} etapas',
        if (p.plantaFoto != null && p.plantaFoto!.isNotEmpty) 'imagem_planta_pc': p.plantaFoto!,
      },
      pontosMedicao: pontosMedicaoDados,
      fotos: p.fotos,
    );
  }

  Future<List<RegistroProvaCargaReal>> montarRegistros(List<PontoProvaCargaBruto> pontos) async {
    final registros = <RegistroProvaCargaReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  // "Tabela geral": uma linha por PONTO DE MEDIÇÃO (não por registro), já
  // que os valores calculados (Condição/Residual/Duração) só existem nesse
  // nível — pedido explícito do usuário ("todos os dados, mais os
  // calculados"). Pura transformação dos registros já montados (não refaz
  // fetch nem re-renderiza gráficos).
  List<Map<String, String>> montarLinhasTabelaGeral(List<RegistroProvaCargaReal> registros) {
    const camposImagem = {'marcacao_elemento_pc', 'imagem_planta_pc', 'grafico_deslocamento_carga_pc', 'tabela_leituras_pc'};
    final linhas = <Map<String, String>>[];
    for (final r in registros) {
      if (r.pontosMedicao.isEmpty) {
        final linha = Map<String, String>.from(r.dados)..removeWhere((k, _) => camposImagem.contains(k));
        linhas.add(linha);
        continue;
      }
      for (final medicao in r.pontosMedicao) {
        final linha = <String, String>{...r.dados, ...medicao}..removeWhere((k, _) => camposImagem.contains(k));
        linhas.add(linha);
      }
    }
    return linhas;
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
    required List<PontoProvaCargaBruto> pontos,
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
}
