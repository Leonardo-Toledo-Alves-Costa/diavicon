import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../../../../modelos_relatorios/charts/relatorio_chart_renderer.dart';
import '../../../../modelos_relatorios/models/foto_relatorio.dart';
import '../../../../modelos_relatorios/models/modelo_relatorio_schema.dart';
import '../../models/extracao_model.dart';

// Busca e calcula os dados reais de Extração e Rompimento de Testemunho pro
// compositor de relatório. Diferente dos demais ensaios, cada REGISTRO aqui
// é 1 Local (`ponto_ensaio_extracao_local`), não 1 elemento — os
// testemunhos (cada um com seu próprio elemento) entram como Bloco de
// repetição. Resistência corrigida é sempre computada por `LeituraExtracaoModel`
// (ver `ExtracaoMath`, fórmula da ABNT NBR 7680-1:2015).
class RegistroExtracaoReal {
  final Map<String, String> dados;
  final List<Map<String, String>> leituras;
  final List<FotoRelatorio> fotos;
  const RegistroExtracaoReal({required this.dados, required this.leituras, required this.fotos});
}

class PontoExtracaoBruto {
  final String nomeLocal; // nome_ponto do ensaio (identifica a campanha)
  final String local; // nome resolvido de estruturas_locais
  final String? plantaMarcada;
  final List<LeituraExtracaoModel> leituras;

  const PontoExtracaoBruto({
    required this.nomeLocal,
    required this.local,
    required this.plantaMarcada,
    required this.leituras,
  });
}

class ExtracaoModeloReportData {
  final SupabaseClient _supabase;
  ExtracaoModeloReportData(this._supabase);

  Future<List<PontoExtracaoBruto>> buscarPontosBrutos({
    required String projetoId,
    required String estruturaId,
    required String tipoEnsaioId,
  }) async {
    final resp = await _supabase
        .from('pontos_ensaios_geral')
        .select('''
          id, nome_ponto,
          ponto_ensaio_extracao_local(
            id, local_id, planta_marcada,
            ponto_ensaio_extracao_leituras(id, criado_em, nome_testemunho, p_x, p_y, foto_ext, foto_cp, foto_rcp, foto_planta, k1, k2, k3, k4, resistencia, resistencia_corrigida, elementos_estruturais(nome, tipo))
          )
        ''')
        .eq('projeto_id', projetoId)
        .eq('estrutura_id', estruturaId)
        .eq('tipo_ensaio_id', tipoEnsaioId);

    final linhas = (resp as List).cast<Map<String, dynamic>>();

    // Resolve nome dos Locais em lote (ponto_ensaio_extracao_local.local_id
    // referencia estruturas_locais, não elementos_estruturais.local).
    final localIds = <String>{};
    for (final p in linhas) {
      final locaisList = p['ponto_ensaio_extracao_local'] as List? ?? const [];
      if (locaisList.isEmpty) continue;
      final localId = (locaisList.first as Map)['local_id']?.toString();
      if (localId != null && localId.isNotEmpty) localIds.add(localId);
    }
    final nomesLocais = <String, String>{};
    if (localIds.isNotEmpty) {
      final locaisResp = await _supabase.from('estruturas_locais').select('id, nome').inFilter('id', localIds.toList());
      for (final l in (locaisResp as List)) {
        nomesLocais[l['id'].toString()] = l['nome']?.toString() ?? '';
      }
    }

    final pontos = <PontoExtracaoBruto>[];
    for (final p in linhas) {
      final locaisList = p['ponto_ensaio_extracao_local'] as List? ?? const [];
      if (locaisList.isEmpty) continue;
      final localJson = (locaisList.first as Map).cast<String, dynamic>();

      final leiturasJson = localJson['ponto_ensaio_extracao_leituras'] as List? ?? const [];
      final leituras = leiturasJson.map((l) => LeituraExtracaoModel.fromJson((l as Map).cast<String, dynamic>())).toList()
        ..sort((a, b) => (a.criadoEm ?? DateTime(0)).compareTo(b.criadoEm ?? DateTime(0)));

      pontos.add(PontoExtracaoBruto(
        nomeLocal: p['nome_ponto']?.toString() ?? '',
        local: nomesLocais[localJson['local_id']?.toString()] ?? 'Desconhecido',
        plantaMarcada: localJson['planta_marcada']?.toString(),
        leituras: leituras,
      ));
    }
    return pontos;
  }

  double _media(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double _desvioPadrao(List<double> v) {
    if (v.length < 2) return 0;
    final m = _media(v);
    return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / v.length);
  }

  double _coefVariacao(List<double> v) {
    final m = _media(v);
    return m == 0 ? 0 : _desvioPadrao(v) / m * 100;
  }

  // ABNT NBR 12655 — valor característico (fck): média - 1,645·desvio.
  double _fck(List<double> v) => _media(v) - 1.645 * _desvioPadrao(v);

  RegistroExtracaoReal _montarRegistroIndividual(PontoExtracaoBruto p) {
    final leiturasDados = p.leituras
        .map((l) => <String, String>{
              'nome_testemunho_ext': l.nomeTestemunho,
              'elemento_leitura_ext': l.elementoNome,
              'tipo_elemento_leitura_ext': l.tipoElemento,
              'direcao_leitura_ext': l.direcao.label,
              'relacao_hd_leitura_ext': l.relacaoHD.toStringAsFixed(2),
              'diametro_leitura_ext': '${l.diametroTestemunho.toStringAsFixed(0)} mm',
              'umidade_leitura_ext': l.condicaoUmidade.label,
              'resistencia_sem_correcao_leitura_ext': '${l.resistenciaSemCorrecao.toStringAsFixed(1)} MPa',
              'resistencia_corrigida_leitura_ext': l.resistenciaComCorrecao != null ? '${l.resistenciaComCorrecao!.toStringAsFixed(1)} MPa' : 'Não permitido',
              if (l.fotoExtraindo != null && l.fotoExtraindo!.isNotEmpty) 'foto_extraindo_leitura_ext': l.fotoExtraindo!,
              if (l.fotoExtracao != null && l.fotoExtracao!.isNotEmpty) 'foto_extracao_leitura_ext': l.fotoExtracao!,
              if (l.fotoRecomposicao != null && l.fotoRecomposicao!.isNotEmpty) 'foto_recomposicao_leitura_ext': l.fotoRecomposicao!,
              if (l.fotoPlanta != null && l.fotoPlanta!.isNotEmpty) 'foto_planta_leitura_ext': l.fotoPlanta!,
            })
        .toList();

    final fotos = <FotoRelatorio>[];
    if (p.plantaMarcada != null && p.plantaMarcada!.isNotEmpty) fotos.add(FotoRelatorio(url: p.plantaMarcada!, descricao: 'Planta — ${p.local}'));
    for (final l in p.leituras) {
      if (l.fotoExtraindo != null && l.fotoExtraindo!.isNotEmpty) fotos.add(FotoRelatorio(url: l.fotoExtraindo!, descricao: '${l.nomeTestemunho} — Extraindo'));
      if (l.fotoExtracao != null && l.fotoExtracao!.isNotEmpty) fotos.add(FotoRelatorio(url: l.fotoExtracao!, descricao: '${l.nomeTestemunho} — Corpo de prova'));
      if (l.fotoRecomposicao != null && l.fotoRecomposicao!.isNotEmpty) fotos.add(FotoRelatorio(url: l.fotoRecomposicao!, descricao: '${l.nomeTestemunho} — Recomposição'));
    }

    return RegistroExtracaoReal(
      dados: {
        'nome_local_ext': p.nomeLocal,
        'local_ext': p.local,
        'total_pontos_ext': p.leituras.length.toString(),
      },
      leituras: leiturasDados,
      fotos: fotos,
    );
  }

  List<RegistroExtracaoReal> montarRegistros(List<PontoExtracaoBruto> pontos) => pontos.map(_montarRegistroIndividual).toList();

  // Pontos de todos os Locais, achatados numa lista só (1 item por
  // testemunho) — usado pra agrupar por Local/Tipo de elemento sem
  // depender de qual Local (registro) cada um veio.
  List<({String local, String tipoElemento, LeituraExtracaoModel leitura})> _testemunhosAchatados(List<PontoExtracaoBruto> pontos) {
    final lista = <({String local, String tipoElemento, LeituraExtracaoModel leitura})>[];
    for (final p in pontos) {
      for (final l in p.leituras) {
        lista.add((local: p.local, tipoElemento: l.tipoElemento.isEmpty ? 'Desconhecido' : l.tipoElemento, leitura: l));
      }
    }
    return lista;
  }

  Future<List<Map<String, String>>> buscarLinhasAgrupadas({
    required List<PontoExtracaoBruto> pontos,
    required HierarquiaAgrupamento hierarquia,
  }) async {
    final testemunhos = _testemunhosAchatados(pontos);
    final grupos = <String, List<({String local, String tipoElemento, LeituraExtracaoModel leitura})>>{};
    final rotulos = <String, ({String local, String tipo})>{};
    for (final t in testemunhos) {
      final String chave;
      switch (hierarquia) {
        case HierarquiaAgrupamento.local:
          chave = t.local;
          break;
        case HierarquiaAgrupamento.tipoElemento:
          chave = t.tipoElemento;
          break;
        case HierarquiaAgrupamento.localTipoElemento:
          chave = '${t.local}|${t.tipoElemento}';
          break;
      }
      grupos.putIfAbsent(chave, () => []).add(t);
      rotulos[chave] = (local: t.local, tipo: t.tipoElemento);
    }

    final linhas = <Map<String, String>>[];
    for (final entrada in grupos.entries) {
      final valores = entrada.value.map((t) => t.leitura.resistenciaComCorrecao).whereType<double>().toList();
      linhas.add({
        'local_grupo_ext': rotulos[entrada.key]!.local,
        'tipo_elemento_grupo_ext': rotulos[entrada.key]!.tipo,
        'total_pontos_grupo_ext': entrada.value.length.toString(),
        'media_resistencia_grupo_ext': valores.isEmpty ? '-' : '${_media(valores).toStringAsFixed(1)} MPa',
        'cv_resistencia_grupo_ext': valores.isEmpty ? '-' : '${_coefVariacao(valores).toStringAsFixed(1)}%',
        'maior_resistencia_grupo_ext': valores.isEmpty ? '-' : '${valores.reduce(max).toStringAsFixed(1)} MPa',
        'menor_resistencia_grupo_ext': valores.isEmpty ? '-' : '${valores.reduce(min).toStringAsFixed(1)} MPa',
        'fck_grupo_ext': valores.length < 2 ? '-' : '${_fck(valores).toStringAsFixed(1)} MPa',
      });
    }
    return linhas;
  }

  Future<String> _barraPor(List<PontoExtracaoBruto> pontos, String Function(String local, String tipo) chaveDe, {required bool ehFck}) async {
    final testemunhos = _testemunhosAchatados(pontos);
    final grupos = <String, List<double>>{};
    for (final t in testemunhos) {
      final valor = t.leitura.resistenciaComCorrecao;
      if (valor == null) continue;
      grupos.putIfAbsent(chaveDe(t.local, t.tipoElemento), () => []).add(valor);
    }
    if (grupos.isEmpty) return '';

    final valoresPorGrupo = ehFck
        ? {for (final e in grupos.entries) e.key: (e.value.length < 2 ? _media(e.value) : _fck(e.value))}
        : {for (final e in grupos.entries) e.key: _media(e.value)};

    final todosValores = valoresPorGrupo.values.toList();
    final mediaGeral = _media(todosValores);

    return RelatorioChartRenderer.barrasComMediaHorizontal(
      grupos: [for (final e in valoresPorGrupo.entries) BarraGrupo(rotulo: e.key, valor: e.value)],
      media: mediaGeral,
      rotuloMedia: ehFck ? 'fck geral' : 'Média geral',
      tituloEixoY: ehFck ? 'fck estimado (MPa)' : 'Resistência corrigida (MPa)',
    );
  }

  Future<Map<String, String>> gerarGraficosAgrupados({
    required Set<String> graficosSelecionados,
    required List<PontoExtracaoBruto> pontos,
  }) async {
    final resultado = <String, String>{};
    if (graficosSelecionados.isEmpty || pontos.isEmpty) return resultado;

    if (graficosSelecionados.contains(chaveGraficoResistenciaElementoExt)) {
      resultado[chaveGraficoResistenciaElementoExt] = await _barraPor(pontos, (local, tipo) => tipo, ehFck: false);
    }
    if (graficosSelecionados.contains(chaveGraficoResistenciaLocalExt)) {
      resultado[chaveGraficoResistenciaLocalExt] = await _barraPor(pontos, (local, tipo) => local, ehFck: false);
    }
    if (graficosSelecionados.contains(chaveGraficoFckElementoExt)) {
      resultado[chaveGraficoFckElementoExt] = await _barraPor(pontos, (local, tipo) => tipo, ehFck: true);
    }
    if (graficosSelecionados.contains(chaveGraficoFckLocalExt)) {
      resultado[chaveGraficoFckLocalExt] = await _barraPor(pontos, (local, tipo) => local, ehFck: true);
    }

    return resultado;
  }

  // "Plantas dos locais" — uma imagem por Local distinto (não passa pelo
  // Quadro configurável de gráficos: é sempre mostrada quando "Registros
  // agrupados" está ativo, ver pedido do usuário "trazer a imagem da planta
  // do local").
  List<FotoRelatorio> montarPlantasPorLocal(List<PontoExtracaoBruto> pontos) {
    final porLocal = <String, String>{};
    for (final p in pontos) {
      if (p.plantaMarcada != null && p.plantaMarcada!.isNotEmpty && !porLocal.containsKey(p.local)) {
        porLocal[p.local] = p.plantaMarcada!;
      }
    }
    return porLocal.entries.map((e) => FotoRelatorio(url: e.value, descricao: e.key)).toList();
  }

  // Mesmo mecanismo de `ChumbadorModeloReportData.buscarReferencial`:
  // Estrutura via embed FK; Tipologia/Revestimento de elemento casam por
  // texto com `elementos_estruturais` (sem Local/Sistema/Tipos de elemento
  // por FK nem Anomalias pra este ensaio — o Local aqui é uma FK própria
  // pra estruturas_locais, não um dos catálogos padrão de Referencial).
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
    required List<PontoExtracaoBruto> pontos,
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
      final valores = pontos.expand((p) => p.leituras.map((l) => l.tipoElemento)).where((v) => v.isNotEmpty).toSet();
      resultado['tipologias_elemento'] = await _buscarCatalogoPorNome('tipologias_elemento', valores, empresaId);
    }

    return resultado;
  }
}
