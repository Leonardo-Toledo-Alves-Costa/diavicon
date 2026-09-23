import 'package:flutter/material.dart';

import 'monte_carlo_bi_model.dart';
import 'serie_bi_model.dart';
import '../utils/cores_bi.dart';

/// Altura máxima de um card, em linhas do grid. Era 4 — pouco para tabelas
/// longas e gráficos com muitas categorias.
const alturaMaximaCardBi = 8;

enum TipoCardBi { grafico, galeria, texto, espaco, badge, tabela, monteCarlo }

enum TipoGraficoBi {
  pizza('Pizza'),
  barra('Barra'),
  barraSegmentada('Barra segmentada por categoria'),
  linhas('Linhas (múltiplas séries)'),
  barraLinha2Eixos('Barra e linha (2 eixos Y)'),
  boxplot('Boxplot'),
  gauss('Distribuição normal (Gauss)'),
  // Várias séries (ver DashboardCardModel.series) — cada uma com o próprio
  // tipo, eixo e cor. Não aparece na lista de tipos do gráfico simples.
  personalizado('Personalizado (várias séries)');

  final String rotulo;
  const TipoGraficoBi(this.rotulo);

  static TipoGraficoBi fromChave(String chave) => TipoGraficoBi.values.firstWhere((t) => t.name == chave, orElse: () => TipoGraficoBi.barra);
}

enum AjusteImagemBi { cobrir, conter }

/// Um card do grid — a unidade que o `schema_json` de `dashboard_modelos`
/// (schema base do modelo) e o `overrides_json` de `dashboard_instancias`
/// (customização por contexto) carregam, um por card, mesclados por `id`.
class DashboardCardModel {
  final String id;
  final TipoCardBi tipo;
  final int gridX;
  final int gridY;
  final int largura; // 1-7
  final int altura; // 1 a alturaMaximaCardBi
  final bool visivel; // toggle manual (olho) — some da automática por ausência de dado

  // ---- grafico ----
  final TipoGraficoBi? tipoGrafico;
  final String? fonteChave; // chave em `catalogoFontesBi`
  final String? campoX;
  final String? estatisticaX; // EstatisticaBi.name
  final String? campoY;
  final String? estatisticaY;
  final String? agruparPor; // 'local' | 'tipoElemento' | 'elemento' | 'data' | null
  final int? corBase; // Color.value

  // ---- galeria ----
  final String? galeriaFonteChave;
  final bool galeriaComLegenda;
  final int galeriaColunas;
  final AjusteImagemBi? galeriaAjuste;

  // ---- texto ----
  final String? textoConteudo;

  // ---- variavel derivada (metrica calculada / multi-ensaio) ----
  // Duas formas, mutuamente exclusivas, porque o usuario escolhe no fim do
  // wizard se a equacao entra na biblioteca da empresa ou vale so ali:
  //
  //  - [variavelId] aponta pra uma linha de `variavel_bi` (reutilizavel,
  //    editavel em Padroes da empresa > Modelos de equacao);
  //  - [variavelInline] guarda a equacao dentro do proprio card.
  //
  // A inline e conveniente pra experimentar, mas fica invisivel fora deste
  // card. [variavelEhLocal] existe pra tela poder sinalizar isso; a marcacao
  // visual e a acao de promover pros padroes ainda nao foram implementadas.
  final String? variavelId;
  final Map<String, dynamic>? variavelInline;

  // ---- grafico personalizado (tipoGrafico == personalizado) ----
  final List<SerieBi> series;

  // ---- tabela ----
  // Uma linha por grupo de [agruparPor] (elemento, local ou tipo).
  final List<ColunaTabelaBi> colunas;

  // ---- badge ----
  // id em `classificadoresBi` (whitehurst, resistividade, carbonatacao).
  final String? classificacaoId;

  // ---- simulacao de Monte Carlo ----
  final ConfigMonteCarloBi? monteCarlo;

  bool get usaVariavel => variavelId != null || variavelInline != null;

  /// Cards cujos dados são várias séries nomeadas (em vez de uma lista
  /// única de pontos): gráfico personalizado, tabela e badge.
  bool get usaSeries =>
      tipo == TipoCardBi.badge ||
      tipo == TipoCardBi.tabela ||
      tipo == TipoCardBi.monteCarlo ||
      tipoGrafico == TipoGraficoBi.personalizado;
  bool get variavelEhLocal => variavelInline != null;

  const DashboardCardModel({
    required this.id,
    required this.tipo,
    required this.gridX,
    required this.gridY,
    required this.largura,
    required this.altura,
    this.visivel = true,
    this.tipoGrafico,
    this.fonteChave,
    this.campoX,
    this.estatisticaX,
    this.campoY,
    this.estatisticaY,
    this.agruparPor,
    this.corBase,
    this.galeriaFonteChave,
    this.galeriaComLegenda = true,
    this.galeriaColunas = 3,
    this.galeriaAjuste,
    this.textoConteudo,
    this.variavelId,
    this.variavelInline,
    this.series = const [],
    this.colunas = const [],
    this.classificacaoId,
    this.monteCarlo,
  });

  Color get cor => Color(corBiNormalizada(corBase ?? corPadraoBiInt));

  DashboardCardModel copyWith({
    String? id,
    TipoCardBi? tipo,
    int? gridX,
    int? gridY,
    int? largura,
    int? altura,
    bool? visivel,
    TipoGraficoBi? tipoGrafico,
    String? fonteChave,
    String? campoX,
    String? estatisticaX,
    String? campoY,
    String? estatisticaY,
    String? agruparPor,
    int? corBase,
    String? galeriaFonteChave,
    bool? galeriaComLegenda,
    int? galeriaColunas,
    AjusteImagemBi? galeriaAjuste,
    String? textoConteudo,
    String? variavelId,
    Map<String, dynamic>? variavelInline,
    List<SerieBi>? series,
    List<ColunaTabelaBi>? colunas,
    String? classificacaoId,
    ConfigMonteCarloBi? monteCarlo,
  }) {
    return DashboardCardModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      largura: largura ?? this.largura,
      altura: altura ?? this.altura,
      visivel: visivel ?? this.visivel,
      tipoGrafico: tipoGrafico ?? this.tipoGrafico,
      fonteChave: fonteChave ?? this.fonteChave,
      campoX: campoX ?? this.campoX,
      estatisticaX: estatisticaX ?? this.estatisticaX,
      campoY: campoY ?? this.campoY,
      estatisticaY: estatisticaY ?? this.estatisticaY,
      agruparPor: agruparPor ?? this.agruparPor,
      corBase: corBase ?? this.corBase,
      galeriaFonteChave: galeriaFonteChave ?? this.galeriaFonteChave,
      galeriaComLegenda: galeriaComLegenda ?? this.galeriaComLegenda,
      galeriaColunas: galeriaColunas ?? this.galeriaColunas,
      galeriaAjuste: galeriaAjuste ?? this.galeriaAjuste,
      textoConteudo: textoConteudo ?? this.textoConteudo,
      variavelId: variavelId ?? this.variavelId,
      variavelInline: variavelInline ?? this.variavelInline,
      series: series ?? this.series,
      colunas: colunas ?? this.colunas,
      classificacaoId: classificacaoId ?? this.classificacaoId,
      monteCarlo: monteCarlo ?? this.monteCarlo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.name,
        'gridX': gridX,
        'gridY': gridY,
        'largura': largura,
        'altura': altura,
        'visivel': visivel,
        if (tipoGrafico != null) 'tipoGrafico': tipoGrafico!.name,
        if (fonteChave != null) 'fonteChave': fonteChave,
        if (campoX != null) 'campoX': campoX,
        if (estatisticaX != null) 'estatisticaX': estatisticaX,
        if (campoY != null) 'campoY': campoY,
        if (estatisticaY != null) 'estatisticaY': estatisticaY,
        if (agruparPor != null) 'agruparPor': agruparPor,
        if (corBase != null) 'corBase': corBase,
        if (galeriaFonteChave != null) 'galeriaFonteChave': galeriaFonteChave,
        'galeriaComLegenda': galeriaComLegenda,
        'galeriaColunas': galeriaColunas,
        if (galeriaAjuste != null) 'galeriaAjuste': galeriaAjuste!.name,
        if (textoConteudo != null) 'textoConteudo': textoConteudo,
        if (variavelId != null) 'variavelId': variavelId,
        if (variavelInline != null) 'variavelInline': variavelInline,
        if (series.isNotEmpty) 'series': series.map((e) => e.toJson()).toList(),
        if (colunas.isNotEmpty) 'colunas': colunas.map((e) => e.toJson()).toList(),
        if (classificacaoId != null) 'classificacaoId': classificacaoId,
        if (monteCarlo != null) 'monteCarlo': monteCarlo!.toJson(),
      };

  factory DashboardCardModel.fromJson(Map<String, dynamic> j) => DashboardCardModel(
        id: j['id'] as String,
        tipo: TipoCardBi.values.firstWhere((t) => t.name == j['tipo'], orElse: () => TipoCardBi.grafico),
        gridX: (j['gridX'] as num?)?.toInt() ?? 0,
        gridY: (j['gridY'] as num?)?.toInt() ?? 0,
        largura: (j['largura'] as num?)?.toInt() ?? 3,
        altura: (j['altura'] as num?)?.toInt() ?? 2,
        visivel: j['visivel'] as bool? ?? true,
        tipoGrafico: j['tipoGrafico'] != null ? TipoGraficoBi.fromChave(j['tipoGrafico'] as String) : null,
        fonteChave: j['fonteChave'] as String?,
        campoX: j['campoX'] as String?,
        estatisticaX: j['estatisticaX'] as String?,
        campoY: j['campoY'] as String?,
        estatisticaY: j['estatisticaY'] as String?,
        agruparPor: j['agruparPor'] as String?,
        corBase: (j['corBase'] as num?)?.toInt(),
        galeriaFonteChave: j['galeriaFonteChave'] as String?,
        galeriaComLegenda: j['galeriaComLegenda'] as bool? ?? true,
        galeriaColunas: (j['galeriaColunas'] as num?)?.toInt() ?? 3,
        galeriaAjuste: j['galeriaAjuste'] != null ? AjusteImagemBi.values.firstWhere((a) => a.name == j['galeriaAjuste'], orElse: () => AjusteImagemBi.cobrir) : null,
        textoConteudo: j['textoConteudo'] as String?,
        variavelId: j['variavelId'] as String?,
        variavelInline: (j['variavelInline'] as Map?)?.cast<String, dynamic>(),
        series: ((j['series'] as List?) ?? const []).whereType<Map>().map((e) => SerieBi.fromJson(e.cast<String, dynamic>())).toList(),
        colunas: ((j['colunas'] as List?) ?? const []).whereType<Map>().map((e) => ColunaTabelaBi.fromJson(e.cast<String, dynamic>())).toList(),
        classificacaoId: j['classificacaoId'] as String?,
        monteCarlo: j['monteCarlo'] is Map ? ConfigMonteCarloBi.fromJson((j['monteCarlo'] as Map).cast<String, dynamic>()) : null,
      );
}

/// Serializa/desserializa a lista de cards de um `schema_json` (modelo) ou
/// `overrides_json` (instância) — ambos guardam a mesma forma: `{"cards": [...]}`.
List<DashboardCardModel> cardsFromSchemaJson(dynamic schemaJson) {
  if (schemaJson == null) return [];
  final lista = (schemaJson is Map ? schemaJson['cards'] : null) as List?;
  if (lista == null) return [];
  return lista.map((c) => DashboardCardModel.fromJson((c as Map).cast<String, dynamic>())).toList();
}

Map<String, dynamic> cardsParaSchemaJson(List<DashboardCardModel> cards) => {
      'cards': cards.map((c) => c.toJson()).toList(),
    };

/// Mescla `overrides` por cima de `base` (por `id` de card) — cards do
/// override substituem o do base; cards só no override (adicionados na
/// instância) entram também; cards do base ausentes no override permanecem.
/// Um override com `"_removidos": [...]` marca ids excluídos pelo usuário.
List<DashboardCardModel> mesclarOverrides(List<DashboardCardModel> base, Map<String, dynamic>? overridesJson) {
  if (overridesJson == null) return base;
  final overrideCards = cardsFromSchemaJson(overridesJson);
  final removidos = ((overridesJson['_removidos'] as List?) ?? const []).map((e) => e.toString()).toSet();
  final porId = <String, DashboardCardModel>{for (final c in base) c.id: c};
  for (final c in overrideCards) {
    porId[c.id] = c;
  }
  for (final id in removidos) {
    porId.remove(id);
  }
  return porId.values.toList();
}
