import 'package:flutter/material.dart' show Color;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/monitoramento_fissura_model.dart';

// Busca e calcula os dados reais de Monitoramento de Fissuras pro compositor
// de relatório. Diferente dos outros ensaios, o status de cada leitura já
// vem PRÉ-CALCULADO e salvo no banco (ver `calcularVariacao`/`StatusFissura.
// calcular` em `monitoramento_fissura_model.dart`, aplicado no momento em
// que a medição é salva) — não recalculamos nada aqui, só lemos.
class RegistroMonitoramentoFissuraReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroMonitoramentoFissuraReal({required this.dados, required this.leituras, required this.fotos});
}

class PontoFissuraBruto {
  final String nomeElemento;
  final String tipoElemento;
  final String local;
  final String revestimento;
  final String? marcacaoImagemUrl;
  final String nomePonto;
  final InstalacaoFissuraModel instalacao;
  final List<Map<String, String>> galeriaGeral; // {url, legenda}

  const PontoFissuraBruto({
    required this.nomeElemento,
    required this.tipoElemento,
    required this.local,
    required this.revestimento,
    required this.marcacaoImagemUrl,
    required this.nomePonto,
    required this.instalacao,
    required this.galeriaGeral,
  });
}

class MonitoramentoFissuraModeloReportData {
  final SupabaseClient _supabase;
  MonitoramentoFissuraModeloReportData(this._supabase);

  Future<List<PontoFissuraBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase
        .from('pontos_ensaios_geral')
        .select('''
          id, nome_ponto,
          elementos_estruturais!inner(nome, tipo, local, revestimento, marcacao_imagem_url, estrutura_id),
          ponto_ensaio_monitoramento_fissura(
            id, data, hora, foto_1, foto_2, selo,
            ponto_ensaio_monitoramento_fissura_leitura(id, data, hora, foto, descricao, temperatura, umidade, medida_x, medida_y, status)
          ),
          galeria_pontos_ensaios_geral(imagem_url, legenda)
        ''')
        .eq('projeto_id', projetoId)
        .eq('elementos_estruturais.estrutura_id', estruturaId)
        .eq('tipo_ensaio_id', tipoEnsaioId);

    final pontos = <PontoFissuraBruto>[];
    for (final p in (resp as List)) {
      final elemento = p['elementos_estruturais'] as Map<String, dynamic>?;
      final instalacaoList = p['ponto_ensaio_monitoramento_fissura'] as List? ?? const [];
      if (instalacaoList.isEmpty) continue;
      final instalacaoJson = (instalacaoList.first as Map).cast<String, dynamic>();

      final leiturasJson = instalacaoJson['ponto_ensaio_monitoramento_fissura_leitura'] as List? ?? const [];
      final medicoes = leiturasJson.map((l) => MedicaoFissuraModel.fromJson((l as Map).cast<String, dynamic>())).toList();

      final instalacao = InstalacaoFissuraModel.fromJson(instalacaoJson, medicoes: medicoes);

      final galeriaGeral = (p['galeria_pontos_ensaios_geral'] as List? ?? const [])
          .map((g) => {'url': g['imagem_url']?.toString() ?? '', 'legenda': g['legenda']?.toString() ?? ''})
          .where((g) => g['url']!.isNotEmpty)
          .toList();

      pontos.add(PontoFissuraBruto(
        nomeElemento: elemento?['nome']?.toString() ?? '',
        tipoElemento: elemento?['tipo']?.toString() ?? 'Desconhecido',
        local: elemento?['local']?.toString() ?? 'Desconhecido',
        revestimento: elemento?['revestimento']?.toString() ?? '',
        marcacaoImagemUrl: elemento?['marcacao_imagem_url']?.toString(),
        nomePonto: p['nome_ponto']?.toString() ?? '',
        instalacao: instalacao,
        galeriaGeral: galeriaGeral,
      ));
    }
    return pontos;
  }

  String _formatarMedicaoData(MedicaoFissuraModel m) =>
      m.dataHora != null ? '${formatarData(m.dataHora!)} ${formatarHora(m.dataHora!)}' : '-';

  // Gráfico "movimento em torno do 0": a trajetória (X,Y) de todas as
  // medições em ordem cronológica — só faz sentido com pelo menos 1 leitura.
  Future<String> _graficoMovimentoXY(List<MedicaoFissuraModel> medicoesOrdenadas) async {
    if (medicoesOrdenadas.isEmpty) return '';
    return RelatorioChartRenderer.planoXYComOrigem(
      pontos: medicoesOrdenadas.map((m) => PontoGrafico(m.medidaX, m.medidaY)).toList(),
    );
  }

  // Gráficos "eixo X/Y ao longo do tempo" — eixo X (tempo) em DIAS desde a
  // instalação (mesma ideia da Carbonatação, que também usa idade numérica
  // em vez de datas de calendário — nenhum RelatorioChartRenderer existente
  // formata datas de calendário no eixo).
  Future<String> _graficoEixoTempo({
    required InstalacaoFissuraModel instalacao,
    required List<MedicaoFissuraModel> medicoesOrdenadas,
    required bool eixoX,
  }) async {
    if (medicoesOrdenadas.isEmpty) return '';
    final referencia = instalacao.dataHora ?? medicoesOrdenadas.first.dataHora;
    if (referencia == null) return '';

    final pontos = medicoesOrdenadas.where((m) => m.dataHora != null).map((m) {
      final dias = m.dataHora!.difference(referencia).inHours / 24.0;
      return PontoGrafico(dias, eixoX ? m.medidaX : m.medidaY);
    }).toList();
    if (pontos.isEmpty) return '';

    return RelatorioChartRenderer.linhaComFaixa(
      series: [SerieLinha(nome: eixoX ? 'Eixo X (mm)' : 'Eixo Y (mm)', pontos: pontos, cor: const Color(0xFFFFA726))],
      tituloEixoX: 'Dias desde a instalação',
      tituloEixoY: eixoX ? 'Eixo X (mm)' : 'Eixo Y (mm)',
    );
  }

  Future<RegistroMonitoramentoFissuraReal> _montarRegistroIndividual(PontoFissuraBruto p) async {
    final instalacao = p.instalacao;
    final medicoes = instalacao.medicoesOrdenadas;
    final ultima = instalacao.ultimaMedicao;

    final graficoXY = await _graficoMovimentoXY(medicoes);
    final graficoX = await _graficoEixoTempo(instalacao: instalacao, medicoesOrdenadas: medicoes, eixoX: true);
    final graficoY = await _graficoEixoTempo(instalacao: instalacao, medicoesOrdenadas: medicoes, eixoX: false);

    // Foto do selo rompido: a foto da leitura mais RECENTE marcada como
    // rompida (não necessariamente a última leitura de todas, se o usuário
    // seguir medindo depois do rompimento).
    final rompidas = medicoes.where((m) => m.rompido && m.foto != null && m.foto!.isNotEmpty).toList();
    final fotoRompimento = rompidas.isEmpty ? null : rompidas.last.foto;

    final leiturasDados = medicoes
        .map((m) => <String, String>{
              'data_hora_leitura_mf': _formatarMedicaoData(m),
              'temperatura_leitura_mf': m.temperatura != null ? '${m.temperatura!.toStringAsFixed(0)}°C' : '-',
              'umidade_leitura_mf': m.umidade != null ? '${m.umidade!.toStringAsFixed(0)}%' : '-',
              'medida_x_leitura_mf': '${m.medidaX.toStringAsFixed(2)} mm',
              'medida_y_leitura_mf': '${m.medidaY.toStringAsFixed(2)} mm',
              'status_leitura_mf': m.status.label,
              'descricao_leitura_mf': m.descricao,
              if (m.foto != null && m.foto!.isNotEmpty) 'foto_leitura_mf': m.foto!,
            })
        .toList();

    final fotos = <FotoRelatorio>[];
    if (instalacao.foto1 != null && instalacao.foto1!.isNotEmpty) fotos.add(FotoRelatorio(url: instalacao.foto1!, descricao: 'Instalação'));
    if (instalacao.foto2 != null && instalacao.foto2!.isNotEmpty) fotos.add(FotoRelatorio(url: instalacao.foto2!, descricao: 'Instalação'));
    for (final m in medicoes) {
      if (m.foto != null && m.foto!.isNotEmpty) fotos.add(FotoRelatorio(url: m.foto!, descricao: 'Leitura ${_formatarMedicaoData(m)}'));
    }
    for (final g in p.galeriaGeral) {
      fotos.add(FotoRelatorio(url: g['url']!, descricao: g['legenda'] ?? ''));
    }

    return RegistroMonitoramentoFissuraReal(
      dados: {
        'nome_elemento_mf': p.nomeElemento,
        'tipo_elemento_mf': p.tipoElemento,
        'local_elemento_mf': p.local,
        'revestimento_elemento_mf': p.revestimento,
        if (p.marcacaoImagemUrl != null && p.marcacaoImagemUrl!.isNotEmpty) 'marcacao_elemento_mf': p.marcacaoImagemUrl!,
        'nome_ponto_mf': p.nomePonto,
        'data_instalacao_mf': instalacao.dataHora != null ? formatarData(instalacao.dataHora!) : '-',
        'tipo_selo_mf': instalacao.tipoSelo.label,
        'temperatura_instalacao_mf': instalacao.temperaturaInstalacao != null ? '${instalacao.temperaturaInstalacao!.toStringAsFixed(0)}°C' : '-',
        'umidade_instalacao_mf': instalacao.umidadeInstalacao != null ? '${instalacao.umidadeInstalacao!.toStringAsFixed(0)}%' : '-',
        if (instalacao.foto1 != null && instalacao.foto1!.isNotEmpty) 'foto_instalacao_1_mf': instalacao.foto1!,
        if (instalacao.foto2 != null && instalacao.foto2!.isNotEmpty) 'foto_instalacao_2_mf': instalacao.foto2!,
        'status_atual_mf': (ultima?.status ?? StatusFissura.estavel).label,
        if (fotoRompimento != null) 'foto_rompimento_mf': fotoRompimento,
        if (graficoXY.isNotEmpty) 'grafico_movimento_xy_mf': graficoXY,
        if (graficoX.isNotEmpty) 'grafico_eixo_x_tempo_mf': graficoX,
        if (graficoY.isNotEmpty) 'grafico_eixo_y_tempo_mf': graficoY,
      },
      leituras: leiturasDados,
      fotos: fotos,
    );
  }

  Future<List<RegistroMonitoramentoFissuraReal>> montarRegistros(List<PontoFissuraBruto> pontos) async {
    final registros = <RegistroMonitoramentoFissuraReal>[];
    for (final p in pontos) {
      registros.add(await _montarRegistroIndividual(p));
    }
    return registros;
  }

  // "Registros agrupados": só contagem por status (ver comentário no
  // catálogo) — sem médias, já que X/Y de fissuras diferentes não são
  // comparáveis entre si.
  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoFissuraBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final grupos = <String, List<PontoFissuraBruto>>{};
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
      var estaveis = 0, leves = 0, alertas = 0, rompidos = 0;
      for (final p in entrada.value) {
        final status = p.instalacao.ultimaMedicao?.status ?? StatusFissura.estavel;
        switch (status) {
          case StatusFissura.estavel:
            estaveis++;
            break;
          case StatusFissura.leve:
            leves++;
            break;
          case StatusFissura.alerta:
            alertas++;
            break;
          case StatusFissura.rompido:
            rompidos++;
            break;
        }
      }
      linhas.add({
        'local_grupo_mf': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_mf': rotulos[entrada.key]!.tipo,
        'total_pontos_grupo_mf': entrada.value.length.toString(),
        'estaveis_grupo_mf': estaveis.toString(),
        'leves_grupo_mf': leves.toString(),
        'alertas_grupo_mf': alertas.toString(),
        'rompidos_grupo_mf': rompidos.toString(),
      });
    }
    return linhas;
  }

  // Sem gráficos-resumo pra Monitoramento de Fissuras (ver comentário no
  // catálogo) — mantido só pra seguir a mesma assinatura usada por
  // `MonitoramentoFissuraModeloReportService`, sempre retornando vazio.
  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoFissuraBruto> pontos,
  }) async {
    return const {};
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
    required List<PontoFissuraBruto> pontos,
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
