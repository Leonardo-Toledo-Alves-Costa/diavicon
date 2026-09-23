import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../empresa/providers/campos_personalizaveis_provider.dart' show DIAVICON_EMPRESA_ID;
import '../models/bi_data_point.dart';
import '../models/bi_filtros_model.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/dashboard_card_model.dart';
import '../models/dashboard_modelo_model.dart';
import '../models/monte_carlo_bi_model.dart';
import '../models/serie_bi_model.dart';
import '../models/variavel_bi_model.dart';
import '../utils/classificadores_bi.dart';
import '../utils/monte_carlo_bi.dart';
import '../utils/variavel_bi_resolver.dart';
import 'variavel_bi_repository.dart';

class DashboardBiRepository {
  final SupabaseClient _s = Supabase.instance.client;

  // ==========================================================================
  // dashboard_modelos
  // ==========================================================================

  /// Modelos da própria empresa + modelos "padrão DIAVICON" (mesmo padrão de
  /// `modelos_relatorio_repository.dart`/`campos_personalizaveis_provider.dart`):
  /// a DIAVICON é a matriz e seus modelos servem de template pra todas as
  /// empresas, que podem usá-los direto (a instância guarda as
  /// customizações em `overrides_json`, nunca altera o modelo original) ou
  /// duplicá-los via [duplicarModelo] pra ter uma cópia própria editável.
  Future<List<DashboardModeloModel>> listarModelos({required String empresaId, required NivelAplicacaoBi nivel}) async {
    final resp = await _s
        .from('dashboard_modelos')
        .select('*')
        .or('empresa_id.eq.$empresaId,empresa_id.eq.$DIAVICON_EMPRESA_ID')
        .eq('nivel_aplicacao', nivel.valor)
        .order('criado_em');
    return (resp as List).map((m) => DashboardModeloModel.fromMap((m as Map).cast<String, dynamic>())).toList();
  }

  Future<DashboardModeloModel?> buscarModelo(String id) async {
    final r = await _s.from('dashboard_modelos').select('*').eq('id', id).maybeSingle();
    return r == null ? null : DashboardModeloModel.fromMap(r);
  }

  Future<String> criarModelo(DashboardModeloModel modelo, {required String empresaId, required String? criadoPor}) async {
    final resp = await _s.from('dashboard_modelos').insert(modelo.toInsertMap(empresaId: empresaId, criadoPor: criadoPor)).select('id').single();
    return resp['id'].toString();
  }

  Future<void> atualizarModelo(String id, DashboardModeloModel modelo) async {
    await _s.from('dashboard_modelos').update(modelo.toUpdateMap()).eq('id', id);
  }

  /// Duplica um modelo (ex.: "Padrão da empresa" -> ponto de partida
  /// editável), marcando a linhagem em `modelo_origem_id`.
  Future<String> duplicarModelo(DashboardModeloModel origem, {required String novoNome, required String empresaId, required String? criadoPor}) async {
    final copia = DashboardModeloModel(
      id: '',
      criadoEm: DateTime.now(),
      empresaId: empresaId,
      nivelAplicacao: origem.nivelAplicacao,
      nome: novoNome,
      isPadrao: false,
      modeloOrigemId: origem.id,
      cards: origem.cards,
    );
    final resp = await _s.from('dashboard_modelos').insert(copia.toInsertMap(empresaId: empresaId, criadoPor: criadoPor)).select('id').single();
    return resp['id'].toString();
  }

  Future<void> excluirModelo(String id) async {
    await _s.from('dashboard_modelos').delete().eq('id', id);
  }

  // ==========================================================================
  // Instâncias — uma tabela POR NÍVEL (dashboard_estruturas_monitoradas,
  // dashboard_projetos, dashboard_estruturas, dashboard_elementos), em vez de
  // uma única `dashboard_instancias` com projeto_id/estrutura_id/elemento_id
  // todos nullable na mesma linha. Cada tabela só tem a coluna de id que
  // aquele nível realmente usa (NOT NULL) — um dashboard de projeto/estrutura
  // não tem sequer onde colocar um elemento_id errado, a classe de bug
  // "id da dimensão errada" fica estruturalmente impossível.
  // ==========================================================================

  String _tabelaParaNivel(NivelAplicacaoBi nivel) => switch (nivel) {
        NivelAplicacaoBi.estruturaMultiProjeto => 'dashboard_estruturas_monitoradas',
        NivelAplicacaoBi.projeto => 'dashboard_projetos',
        NivelAplicacaoBi.estruturaNoProjeto => 'dashboard_estruturas',
        NivelAplicacaoBi.elementoNoProjeto => 'dashboard_elementos',
      };

  /// Busca a instância salva para [nivel] — cada nível tem sua própria
  /// tabela, então não há mais chance de cruzar projeto/estrutura/elemento
  /// fora do que aquele nível usa.
  Future<DashboardInstanciaModel?> buscarInstancia({
    required NivelAplicacaoBi nivel,
    String? projetoId,
    String? estruturaId,
    String? elementoId,
  }) async {
    final tabela = _tabelaParaNivel(nivel);
    var q = _s.from(tabela).select('*');
    switch (nivel) {
      case NivelAplicacaoBi.elementoNoProjeto:
        if (elementoId == null) return null;
        q = q.eq('elemento_id', elementoId);
        break;
      case NivelAplicacaoBi.estruturaNoProjeto:
        if (estruturaId == null) return null;
        q = q.eq('estrutura_id', estruturaId);
        break;
      case NivelAplicacaoBi.estruturaMultiProjeto:
        if (estruturaId == null) return null;
        q = q.eq('estrutura_id', estruturaId);
        break;
      case NivelAplicacaoBi.projeto:
        if (projetoId == null) return null;
        q = q.eq('projeto_id', projetoId);
        break;
    }
    final r = await q.maybeSingle();
    return r == null ? null : DashboardInstanciaModel.fromMap(r);
  }

  Future<String> criarInstancia(DashboardInstanciaModel instancia) async {
    final tabela = _tabelaParaNivel(instancia.nivelAplicacao);
    final resp = await _s.from(tabela).insert(instancia.toInsertMap()).select('id').single();
    return resp['id'].toString();
  }

  Future<void> salvarOverrides(String instanciaId, Map<String, dynamic> overridesJson, NivelAplicacaoBi nivel) async {
    await _s.from(_tabelaParaNivel(nivel)).update({'overrides_json': overridesJson}).eq('id', instanciaId);
  }

  /// Apaga a instância deste contexto — único jeito de trocar de modelo:
  /// não existe "trocar" in-place, o usuário exclui e escolhe outro na tela
  /// de seleção, que volta a aparecer em seguida.
  Future<void> excluirInstancia(String instanciaId, NivelAplicacaoBi nivel) async {
    await _s.from(_tabelaParaNivel(nivel)).delete().eq('id', instanciaId);
  }

  // ==========================================================================
  // Opções de filtro — cada nível oferece um subconjunto diferente (ver
  // `BiOpcoesFiltro`), sempre calculado a partir do que EXISTE no contexto
  // atual, não de um catálogo global da empresa.
  // ==========================================================================

  Future<BiOpcoesFiltro> buscarOpcoesFiltro(NivelAplicacaoBi nivel, {String? projetoId, String? estruturaId}) async {
    try {
      switch (nivel) {
        case NivelAplicacaoBi.elementoNoProjeto:
          return const BiOpcoesFiltro();

        case NivelAplicacaoBi.estruturaMultiProjeto:
          if (estruturaId == null) return const BiOpcoesFiltro();
          final vinculos = await _s.from('projeto_estruturas').select('projeto_id, projetos(nome)').eq('estrutura_id', estruturaId);
          final projetos = (vinculos as List)
              .map((v) => BiOpcaoFiltro(v['projeto_id'].toString(), (v['projetos'] as Map?)?['nome']?.toString() ?? 'Sem nome'))
              .toList();
          final basicos = await _opcoesBasicasDeElementos(estruturaIds: [estruturaId]);
          return BiOpcoesFiltro(projetos: projetos, locais: basicos.locais, tiposElemento: basicos.tiposElemento, sistemas: basicos.sistemas);

        case NivelAplicacaoBi.projeto:
          if (projetoId == null) return const BiOpcoesFiltro();
          final vinculos = await _s.from('projeto_estruturas').select('estrutura_id, estruturas(nome, conjunto_estrutural_id, conjuntos_estruturais(nome))').eq('projeto_id', projetoId);
          final estruturas = <BiOpcaoFiltro>[];
          final conjuntosMap = <String, String>{};
          for (final v in (vinculos as List)) {
            final estr = v['estruturas'] as Map?;
            estruturas.add(BiOpcaoFiltro(v['estrutura_id'].toString(), estr?['nome']?.toString() ?? 'Sem nome'));
            final conjuntoId = estr?['conjunto_estrutural_id']?.toString();
            final conjuntoNome = (estr?['conjuntos_estruturais'] as Map?)?['nome']?.toString();
            if (conjuntoId != null && conjuntoNome != null) conjuntosMap[conjuntoId] = conjuntoNome;
          }
          final estrIds = estruturas.map((e) => e.id).toList();
          final basicos = await _opcoesBasicasDeElementos(estruturaIds: estrIds);
          return BiOpcoesFiltro(
            estruturas: estruturas,
            conjuntosEstruturais: conjuntosMap.entries.map((e) => BiOpcaoFiltro(e.key, e.value)).toList(),
            locais: basicos.locais,
            tiposElemento: basicos.tiposElemento,
            sistemas: basicos.sistemas,
          );

        case NivelAplicacaoBi.estruturaNoProjeto:
          if (estruturaId == null) return const BiOpcoesFiltro();
          final basicos = await _opcoesBasicasDeElementos(estruturaIds: [estruturaId]);
          return BiOpcoesFiltro(locais: basicos.locais, tiposElemento: basicos.tiposElemento, sistemas: basicos.sistemas);
      }
    } catch (_) {
      return const BiOpcoesFiltro();
    }
  }

  Future<({List<String> locais, List<String> tiposElemento, List<BiOpcaoFiltro> sistemas})> _opcoesBasicasDeElementos({required List<String> estruturaIds}) async {
    if (estruturaIds.isEmpty) return (locais: <String>[], tiposElemento: <String>[], sistemas: <BiOpcaoFiltro>[]);
    final elementos = await _s.from('elementos_estruturais').select('local, tipo').inFilter('estrutura_id', estruturaIds);
    final locais = <String>{};
    final tipos = <String>{};
    for (final e in (elementos as List)) {
      final local = e['local']?.toString();
      final tipo = e['tipo']?.toString();
      if (local != null && local.isNotEmpty) locais.add(local);
      if (tipo != null && tipo.isNotEmpty) tipos.add(tipo);
    }
    List<BiOpcaoFiltro> sistemas = [];
    if (tipos.isNotEmpty) {
      final tiposResp = await _s.from('tipos_elemento').select('sistemas_id, sistemas_habitacionais(nome)').inFilter('nome', tipos.toList());
      final sistemasMap = <String, String>{};
      for (final t in (tiposResp as List)) {
        final sid = t['sistemas_id']?.toString();
        final snome = (t['sistemas_habitacionais'] as Map?)?['nome']?.toString();
        if (sid != null && snome != null) sistemasMap[sid] = snome;
      }
      sistemas = sistemasMap.entries.map((e) => BiOpcaoFiltro(e.key, e.value)).toList();
    }
    return (locais: locais.toList()..sort(), tiposElemento: tipos.toList()..sort(), sistemas: sistemas);
  }

  // ==========================================================================
  // Dados ao vivo por card
  // ==========================================================================

  /// Busca os `BiDataPoint` de um card (eixo X, já resolvido conforme o
  /// fetcher da fonte escolhida). `estatisticaX` decide Média/Desvio/CV
  /// quando `CategoriaDadoBi.estatistica`; ignorado nos demais.
  Future<List<BiDataPoint>> buscarDadosCard(DashboardCardModel card, BiContexto ctx) async {
    // Card de variável derivada (métrica calculada / multi-ensaio): o valor
    // não vem de um campo do catálogo, é calculado por elemento a partir de
    // um ou mais campos. Ver `buscarResultadoVariavel`, que também devolve
    // quantos elementos ficaram sem dado.
    if (card.usaVariavel) {
      final resultado = await buscarResultadoVariavel(card, ctx);
      return resultado.pontos;
    }
    if (card.fonteChave == null || card.campoX == null) return [];
    final campo = buscarCampoBi(card.fonteChave!, card.campoX!);
    if (campo == null) return [];
    final estatistica = card.estatisticaX != null ? EstatisticaBi.values.firstWhere((e) => e.name == card.estatisticaX, orElse: () => EstatisticaBi.media) : null;
    return campo.buscar(ctx, estatistica: estatistica);
  }

  /// Busca a SEGUNDA série de um card (linha do 2-eixos, ou a categoria de
  /// segmentação do barra-segmentada) — mesmo campo `campoY`/`estatisticaY`
  /// que o construtor de eixos preenche, ver `construtor_eixos_modal.dart`.
  Future<List<BiDataPoint>> buscarDadosCardSecundarios(DashboardCardModel card, BiContexto ctx) async {
    if (card.fonteChave == null || card.campoY == null) return [];
    final campo = buscarCampoBi(card.fonteChave!, card.campoY!);
    if (campo == null) return [];
    final estatistica = card.estatisticaY != null ? EstatisticaBi.values.firstWhere((e) => e.name == card.estatisticaY, orElse: () => EstatisticaBi.media) : null;
    return campo.buscar(ctx, estatistica: estatistica);
  }

  /// Resolve a variável derivada de um card, seja ela salva nos padrões da
  /// empresa ([DashboardCardModel.variavelId]) ou local ao card
  /// ([DashboardCardModel.variavelInline]).
  ///
  /// Devolve também a contagem de elementos sem dado. `buscarDadosCard`
  /// descarta essa contagem hoje (o cache do dashboard só guarda pontos) —
  /// use este método direto quando for exibir a lacuna na tela.
  Future<ResultadoVariavelBi> buscarResultadoVariavel(DashboardCardModel card, BiContexto ctx) async {
    VariavelBiModel? variavel;

    if (card.variavelInline != null) {
      variavel = VariavelBiModel.fromMap(card.variavelInline!);
    } else if (card.variavelId != null) {
      variavel = await VariavelBiRepository(_s).buscar(card.variavelId!);
    }

    // Variável excluída dos padrões da empresa depois que o card foi criado:
    // o card fica sem dado em vez de quebrar o dashboard inteiro.
    if (variavel == null) return ResultadoVariavelBi.vazio;

    return VariavelBiResolver.resolver(variavel, ctx);
  }

  /// Resolve uma referência de valor: um campo do catálogo (com a
  /// estatística escolhida) ou uma equação, salva ou embutida.
  Future<List<BiDataPoint>> buscarReferencia(ReferenciaValorBi ref, BiContexto ctx) async {
    if (ref.ehVariavel) {
      final variavel = ref.variavelInline != null
          ? VariavelBiModel.fromMap(ref.variavelInline!)
          : await VariavelBiRepository(_s).buscar(ref.variavelId!);
      // Equação excluída dos padrões depois de o card ser criado.
      if (variavel == null) return const [];
      return (await VariavelBiResolver.resolver(variavel, ctx)).pontos;
    }
    if (ref.fonte == null || ref.campo == null) return const [];
    final campo = buscarCampoBi(ref.fonte!, ref.campo!);
    if (campo == null) return const [];
    final estatistica = ref.estatistica == null
        ? null
        : EstatisticaBi.values.firstWhere((e) => e.name == ref.estatistica, orElse: () => EstatisticaBi.media);
    return campo.buscar(ctx, estatistica: estatistica);
  }

  /// Dados dos cards de várias séries — gráfico personalizado, tabela e
  /// badge —, como `id da série/coluna/entrada -> pontos`.
  ///
  /// As referências são buscadas em paralelo e isoladas: uma série que
  /// falha (campo removido do catálogo, erro de rede) volta vazia sem
  /// derrubar as outras do mesmo card.
  Future<Map<String, List<BiDataPoint>>> buscarSeriesCard(DashboardCardModel card, BiContexto ctx) async {
    final refs = <String, ReferenciaValorBi>{};
    if (card.tipo == TipoCardBi.badge) {
      refs.addAll(buscarClassificadorBi(card.classificacaoId)?.entradas ?? const {});
    } else if (card.tipo == TipoCardBi.tabela) {
      for (final coluna in card.colunas) {
        refs[coluna.id] = coluna.valor;
      }
    } else if (card.tipoGrafico == TipoGraficoBi.personalizado) {
      for (final serie in card.series) {
        refs[serie.id] = serie.valor;
      }
    } else if (card.tipo == TipoCardBi.monteCarlo && card.monteCarlo != null) {
      final mc = card.monteCarlo!;
      if (mc.analise == AnaliseMonteCarloBi.despassivacao) {
        refs.addAll(entradasDespassivacaoMC);
      } else {
        for (final serie in mc.series.where((s) => !s.derivada && s.valor != null)) {
          refs[serie.id] = referenciaParaSimulacao(serie.valor!);
        }
      }
    }

    final entradas = refs.entries.toList();
    final resultados = await Future.wait(entradas.map((e) async {
      try {
        return await buscarReferencia(e.value, ctx);
      } catch (erro) {
        debugPrint('[Dashboard] série "${e.key}" do card ${card.id} falhou: $erro');
        return const <BiDataPoint>[];
      }
    }));
    return {for (var i = 0; i < entradas.length; i++) entradas[i].key: resultados[i]};
  }

  /// Checagem rápida de existência de dado (visibilidade automática) — não
  /// é salva, recalculada a cada load.
  Future<bool> cardTemDado(DashboardCardModel card, BiContexto ctx) async {
    if (card.tipo == TipoCardBi.texto || card.tipo == TipoCardBi.espaco) return true;
    final pontos = await buscarDadosCard(card, ctx);
    return pontos.isNotEmpty;
  }

  /// Agrupa os pontos por `agruparPor` (local/tipoElemento/elemento/data) e
  /// resolve o valor de cada grupo — para campos categóricos, é a contagem;
  /// para brutos/estatística já resolvidos no fetcher, é a média do grupo
  /// (relevante quando "Agrupar por" junta múltiplos elementos).
  ///
  /// [agregacao] `soma` é para pontuações acumuláveis (GUT da inspeção
  /// visual): o grupo vale a soma dos pontos, não a média.
  Map<String, double> agruparValores(List<BiDataPoint> pontos, String? agruparPor, {AgregacaoBi agregacao = AgregacaoBi.media}) =>
      agruparValoresBi(pontos, agruparPor, agregacao: agregacao);

  /// Agregação de uma referência: a do campo do catálogo; equações sempre
  /// por média (são grandezas físicas, não pontuações).
  static AgregacaoBi agregacaoDe(ReferenciaValorBi ref) {
    if (ref.ehVariavel || ref.fonte == null || ref.campo == null) return AgregacaoBi.media;
    return buscarCampoBi(ref.fonte!, ref.campo!)?.agregacao ?? AgregacaoBi.media;
  }

  Map<String, int> contarCategorias(List<BiDataPoint> pontos, {String? agruparPor}) {
    final contagem = <String, int>{};
    for (final p in pontos) {
      final chave = p.categoria ?? 'Sem dado';
      contagem[chave] = (contagem[chave] ?? 0) + 1;
    }
    return contagem;
  }

  /// Fotos da galeria de um card do tipo Galeria — junta
  /// `galeria_pontos_ensaios_geral` aos pontos do ensaio (ou de TODOS os
  /// ensaios, se `fonteChave` for `dados_gerais`) dentro do contexto do
  /// dashboard.
  Future<List<Map<String, String?>>> buscarGaleriaCard(String? fonteChave, BiContexto ctx) async {
    try {
      var pontosQ = _s.from('pontos_ensaios_geral').select('id');
      if (fonteChave != null && fonteChave != 'dados_gerais') {
        final fonte = buscarFonteBi(fonteChave);
        if (fonte?.tipoEnsaio != null) {
          final tipoEnsaioId = await resolverTipoEnsaioIdBi(fonte!.tipoEnsaio!);
          if (tipoEnsaioId == null) return [];
          pontosQ = pontosQ.eq('tipo_ensaio_id', tipoEnsaioId);
        }
      }
      if (ctx.elementoId != null) {
        pontosQ = pontosQ.eq('elemento_estrutural_id', ctx.elementoId!);
      } else if (ctx.estruturaId != null) {
        pontosQ = pontosQ.eq('estrutura_id', ctx.estruturaId!);
      } else if (ctx.projetoId != null) {
        pontosQ = pontosQ.eq('projeto_id', ctx.projetoId!);
      } else {
        return [];
      }
      final pontosResp = await pontosQ;
      final pontosIds = (pontosResp as List).map((p) => p['id'].toString()).toList();
      if (pontosIds.isEmpty) return [];
      final galeriaResp = await _s.from('galeria_pontos_ensaios_geral').select('imagem_url, legenda').inFilter('ponto_ensaio_id', pontosIds).limit(60);
      return (galeriaResp as List).map((g) => {'url': g['imagem_url']?.toString(), 'legenda': g['legenda']?.toString()}).where((g) => g['url'] != null).toList();
    } catch (_) {
      return [];
    }
  }

}

/// Rótulo do grupo de um ponto para [agruparPor]. Função pura (fora do
/// repositório) para poder ser usada e testada sem cliente Supabase.
String chaveAgrupamentoBi(BiDataPoint p, String? agruparPor) {
  switch (agruparPor) {
    case 'tipoElemento':
      return p.tipoElemento;
    case 'elemento':
      return p.elementoNome;
    case 'data':
      return p.data?.toIso8601String().substring(0, 10) ?? 'Sem data';
    case 'local':
      return p.local;
    case 'estrutura':
      return p.estrutura.isEmpty ? 'Desconhecida' : p.estrutura;
    default:
      // Campos sem "Agrupar por" (Idade/CAA, RDO clima/trabalho — ver
      // `CampoBiCatalogo.opcoesAgrupamento`)
      // não têm `agruparPor` nenhum: usa a própria categoria do ponto
      // quando existir (RDO clima/trabalho já são categóricos por
      // natureza), senão um balde único — nunca `p.local`, que fica em
      // branco pra esses campos e juntaria tudo "sem querer" num só grupo
      // com nome vazio.
      return p.categoria ?? 'Geral';
  }
}

/// Valor de cada grupo: média ou soma dos pontos, conforme [agregacao].
/// Função pura — ver [DashboardBiRepository.agruparValores].
Map<String, double> agruparValoresBi(List<BiDataPoint> pontos, String? agruparPor, {AgregacaoBi agregacao = AgregacaoBi.media}) {
  final grupos = <String, List<double>>{};
  for (final p in pontos) {
    if (p.valor == null) continue;
    grupos.putIfAbsent(chaveAgrupamentoBi(p, agruparPor), () => []).add(p.valor!);
  }
  return grupos.map((k, v) {
    final soma = v.reduce((a, b) => a + b);
    return MapEntry(k, agregacao == AgregacaoBi.soma ? soma : soma / v.length);
  });
}
