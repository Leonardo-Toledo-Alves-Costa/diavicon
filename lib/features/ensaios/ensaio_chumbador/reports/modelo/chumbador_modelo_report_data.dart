import 'dart:math';

import 'package:flutter/material.dart' show Colors;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/chumbador_model.dart';

// Busca e calcula os dados reais de Tração em Chumbador pro compositor de
// relatório. Carga máxima/deslocamento máximo já vêm calculados e salvos no
// registro do ensaio (ver `ChumbadorModel`/`ChumbadorRepository`) — não
// recalculamos nada aqui além do que é específico do relatório (gráfico e
// agregações por grupo).
class RegistroChumbadorReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroChumbadorReal({required this.dados, required this.leituras, required this.fotos});
}

class PontoChumbadorBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final ChumbadorModel ensaio;
  final List<Map<String, String>> galeriaGeral; // {url, legenda}

  const PontoChumbadorBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.ensaio,
    required this.galeriaGeral,
  });
}

class ChumbadorModeloReportData {
  final SupabaseClient _supabase;
  ChumbadorModeloReportData(this._supabase);

  Future<List<PontoChumbadorBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase
        .from('pontos_ensaios_geral')
        .select('''
          id, nome_ponto,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_tracao(
            id, foto_antes, foto_durante, foto_apos, ocorrencia_geral, cond_avaliar,
            ponto_ensaio_tracao_leitura(id, criado_em, etapa, carga, deslocamento, foto, ocorrencia)
          ),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''')
        .eq('projeto_id', projetoId)
        .eq('elementos_estruturais.estrutura_id', estruturaId)
        .eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoChumbadorBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final ensaioList = p['ponto_ensaio_tracao'] as List? ?? const [];
      if (ensaioList.isEmpty) continue;
      final ensaioJson = (ensaioList.first as Map).cast<String, dynamic>();

      final leiturasJson = ensaioJson['ponto_ensaio_tracao_leitura'] as List? ?? const [];
      final leituras = leiturasJson.map((l) => LeituraChumbadorModel.fromJson((l as Map).cast<String, dynamic>())).toList();

      final ensaio = ChumbadorModel.fromJson(ensaioJson, leituras: leituras);

      final galeriaGeral = (p['galeria_pontos_ensaios_geral'] as List? ?? const [])
          .map((g) => {'url': g['imagem_url']?.toString() ?? '', 'legenda': g['legenda']?.toString() ?? ''})
          .where((g) => g['url']!.isNotEmpty)
          .toList();

      pontos.add(PontoChumbadorBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        ensaio: ensaio,
        galeriaGeral: galeriaGeral,
      ));
    }
    return pontos;
  }

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

  // Gráfico "força × deslocamento": duas séries (Carregamento/
  // Descarregamento), cada uma ordenada por `criado_em` — a tabela real não
  // tem número de leitura manual (ver `LeituraChumbadorModel`).
  Future<String> _graficoForcaDeslocamento(ChumbadorModel ensaio) async {
    final carregamento = ensaio.leiturasCarregamento.map((l) => PontoGrafico(l.deslocamentoMm, l.forcaKn)).toList();
    final descarregamentoLido = ensaio.leiturasDescarregamento.map((l) => PontoGrafico(l.deslocamentoMm, l.forcaKn)).toList();
    if (carregamento.isEmpty && descarregamentoLido.isEmpty) return '';

    // Liga o último ponto do carregamento ao primeiro do descarregamento —
    // é a mesma curva contínua do ensaio (o pico), não duas curvas soltas.
    final descarregamento =
        carregamento.isNotEmpty && descarregamentoLido.isNotEmpty ? [carregamento.last, ...descarregamentoLido] : descarregamentoLido;

    return RelatorioChartRenderer.linhaComFaixa(
      series: [
        SerieLinha(nome: EtapaLeituraChumbador.carregamento.label, pontos: carregamento, cor: EtapaLeituraChumbador.carregamento.cor),
        SerieLinha(nome: EtapaLeituraChumbador.descarregamento.label, pontos: descarregamento, cor: EtapaLeituraChumbador.descarregamento.cor),
      ],
      tituloEixoX: 'Deslocamento (mm)',
      tituloEixoY: 'Força (kN)',
    );
  }

  Future<RegistroChumbadorReal> _montarRegistroIndividual(PontoChumbadorBruto p) async {
    final ensaio = p.ensaio;
    final grafico = await _graficoForcaDeslocamento(ensaio);

    final leiturasOrdenadas = ensaio.leiturasOrdenadas;
    final leiturasDados = leiturasOrdenadas
        .map((l) => <String, String>{
              'etapa_leitura_ch': l.etapa.label,
              'forca_leitura_ch': '${l.forcaKn.toStringAsFixed(1)} kN',
              'deslocamento_leitura_ch': '${l.deslocamentoMm.toStringAsFixed(2)} mm',
              'ocorrencia_leitura_ch': l.ocorrencia,
              if (l.foto != null && l.foto!.isNotEmpty) 'foto_leitura_ch': l.foto!,
            })
        .toList();

    final fotos = <FotoRelatorio>[];
    if (ensaio.fotoChumbador != null && ensaio.fotoChumbador!.isNotEmpty) fotos.add(FotoRelatorio(url: ensaio.fotoChumbador!, descricao: 'Chumbador'));
    if (ensaio.fotoDurante != null && ensaio.fotoDurante!.isNotEmpty) fotos.add(FotoRelatorio(url: ensaio.fotoDurante!, descricao: 'Durante o ensaio'));
    if (ensaio.fotoApos != null && ensaio.fotoApos!.isNotEmpty) fotos.add(FotoRelatorio(url: ensaio.fotoApos!, descricao: 'Após o ensaio'));
    for (var i = 0; i < leiturasOrdenadas.length; i++) {
      final l = leiturasOrdenadas[i];
      if (l.foto != null && l.foto!.isNotEmpty) fotos.add(FotoRelatorio(url: l.foto!, descricao: 'Leitura ${i + 1} (${l.etapa.label})'));
    }
    for (final g in p.galeriaGeral) {
      fotos.add(FotoRelatorio(url: g['url']!, descricao: g['legenda'] ?? ''));
    }

    return RegistroChumbadorReal(
      dados: {
        'nome_elemento_ch': p.nomeElemento,
        'tipo_elemento_ch': p.tipoElemento,
        'local_elemento_ch': p.local,
        'revestimento_elemento_ch': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_ch': p.marcacaoImagemUrl!,
        'nome_ponto_ch': p.nomePonto,
        if (ensaio.fotoChumbador != null && ensaio.fotoChumbador!.isNotEmpty) 'foto_chumbador_ch': ensaio.fotoChumbador!,
        if (ensaio.fotoDurante != null && ensaio.fotoDurante!.isNotEmpty) 'foto_durante_ch': ensaio.fotoDurante!,
        if (ensaio.fotoApos != null && ensaio.fotoApos!.isNotEmpty) 'foto_apos_ch': ensaio.fotoApos!,
        'ocorrencias_gerais_ch': ensaio.ocorrenciasGerais,
        'carga_maxima_ch': ensaio.cargaMaxima != null ? '${ensaio.cargaMaxima!.toStringAsFixed(1)} kN' : '-',
        'deslocamento_maximo_ch': ensaio.deslocamentoMaximo != null ? '${ensaio.deslocamentoMaximo!.toStringAsFixed(1)} mm' : '-',
        'condicao_avaliacao_ch': ensaio.condicaoAvaliacao?.label ?? 'Pendente',
        if (grafico.isNotEmpty) 'grafico_forca_deslocamento_ch': grafico,
      },
      leituras: leiturasDados,
      fotos: fotos,
    );
  }

  Future<List<RegistroChumbadorReal>> montarRegistros(List<PontoChumbadorBruto> pontos) async {
    final registros = <RegistroChumbadorReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoChumbadorBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoChumbadorBruto>>{};
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
      final cargas = entrada.value.map((p) => p.ensaio.cargaMaxima).whereType<double>().toList();
      final media = _media(cargas);
      var aprovados = 0, reprovados = 0, cabeAnalise = 0;
      for (final p in entrada.value) {
        switch (p.ensaio.condicaoAvaliacao) {
          case CondicaoAvaliacaoChumbador.aprovado:
            aprovados++;
            break;
          case CondicaoAvaliacaoChumbador.reprovado:
            reprovados++;
            break;
          case CondicaoAvaliacaoChumbador.cabeAnalise:
          case null:
            cabeAnalise++;
            break;
        }
      }
      linhas.add({
        'local_grupo_ch': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_ch': rotulos[entrada.key]!.tipo,
        'total_pontos_grupo_ch': entrada.value.length.toString(),
        'media_carga_grupo_ch': cargas.isEmpty ? '-' : '${media.toStringAsFixed(1)} kN',
        'cv_carga_grupo_ch': cargas.isEmpty ? '-' : '${_coefVariacao(cargas).toStringAsFixed(1)}%',
        'maior_carga_grupo_ch': cargas.isEmpty ? '-' : '${cargas.reduce(max).toStringAsFixed(1)} kN',
        'menor_carga_grupo_ch': cargas.isEmpty ? '-' : '${cargas.reduce(min).toStringAsFixed(1)} kN',
        'aprovados_grupo_ch': aprovados.toString(),
        'reprovados_grupo_ch': reprovados.toString(),
        'cabe_analise_grupo_ch': cabeAnalise.toString(),
      });
    }
    return linhas;
  }

  // Boxplot único: uma caixa por combinação Local + Tipo de elemento (ver
  // comentário em `modelo_relatorio_schema.dart`), sempre nessa
  // granularidade — independente da hierarquia escolhida pra tabela
  // agrupada (mesmo padrão de chaves fixas dos outros ensaios).
  Future<String> _boxplotLocalTipo(List<PontoChumbadorBruto> pontos) async {
    final grupos = <String, List<double>>{};
    for (final p in pontos) {
      final carga = p.ensaio.cargaMaxima;
      if (carga == null) continue;
      grupos.putIfAbsent('${p.local} / ${p.tipoElemento}', () => []).add(carga);
    }
    final rotulos = grupos.keys.toList();
    if (rotulos.isEmpty) return '';

    return RelatorioChartRenderer.boxplotPorGrupo(
      series: [
        SerieBoxplot(
          nome: 'Carga máxima (kN)',
          cor: Colors.blueGrey,
          grupos: [
            for (final r in rotulos)
              GrupoBoxplot(
                rotulo: r,
                minimo: grupos[r]!.reduce(min),
                media: _media(grupos[r]!),
                maximo: grupos[r]!.reduce(max),
              ),
          ],
        ),
      ],
      tituloEixoY: 'Carga máxima (kN)',
    );
  }

  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoChumbadorBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoBoxplotLocalTipoChumbador)) {
      resultado[chaveGraficoBoxplotLocalTipoChumbador] = await _boxplotLocalTipo(pontos);
    }

    return resultado;
  }

  // Mesmo mecanismo de `ResistividadeModeloReportData.buscarReferencial`:
  // Estrutura via embed FK; Tipologia/Revestimento de elemento casam por
  // texto com `elementos_estruturais` (sem Local/Sistema/Tipos de elemento
  // por FK nem Anomalias pra este ensaio).
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
    required List<PontoChumbadorBruto> pontos,
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
