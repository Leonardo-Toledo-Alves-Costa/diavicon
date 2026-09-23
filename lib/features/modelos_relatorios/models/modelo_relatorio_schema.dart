import 'quadro_model.dart';

// Estrutura de configuração (schema_json) de um modelo de relatório.
// As 5 seções do relatório: Cabeçalho, Informações iniciais, Registros,
// Galeria e Tabela resumo — cada uma com seu próprio "ativo" (liga/desliga).
//
// Cabeçalho e Registros são montados com o editor de Quadro (Linha/Divisão/
// Slot) — não são checkboxes. Informações iniciais usa o mesmo editor, só
// que em 3 blocos de repetição nomeados e fixos (equipe, empresas do
// projeto, estruturas do projeto), cada um com seu próprio Quadro.

class ModeloRelatorioSchema {
  final SecaoQuadroConfig cabecalho;
  final InformacoesIniciaisConfig informacoesIniciais;
  final ReferencialConfig referencial;
  final SecaoQuadroConfig registros;
  final SecaoQuadroConfig analiseElementos;
  final RegistrosAgrupadosConfig registrosAgrupados;
  final GutSomatorioConfig gutSomatorio;
  final GaleriaConfig galeria;
  final ResumoConfig resumo;
  final DecoracaoGlobalConfig decoracao;

  const ModeloRelatorioSchema({
    required this.cabecalho,
    required this.informacoesIniciais,
    required this.referencial,
    required this.registros,
    required this.analiseElementos,
    required this.registrosAgrupados,
    required this.gutSomatorio,
    required this.galeria,
    required this.resumo,
    required this.decoracao,
  });

  factory ModeloRelatorioSchema.vazio() => ModeloRelatorioSchema(
        cabecalho: const SecaoQuadroConfig(ativo: true, quadro: Quadro(linhas: [])),
        informacoesIniciais: InformacoesIniciaisConfig.vazio(),
        referencial: ReferencialConfig.vazio(),
        registros: const SecaoQuadroConfig(ativo: true, quadro: Quadro(linhas: [])),
        // Só a Ultrassonografia usa (ver EnsaioModeloConfig.suportaAnaliseElementos)
        // — desativada por padrão pra não aparecer em branco nos outros ensaios.
        analiseElementos: const SecaoQuadroConfig(ativo: false, quadro: Quadro(linhas: [])),
        registrosAgrupados: RegistrosAgrupadosConfig.vazio(),
        gutSomatorio: GutSomatorioConfig.vazio(),
        galeria: GaleriaConfig.vazio(),
        resumo: ResumoConfig.vazio(),
        decoracao: DecoracaoGlobalConfig.vazio(),
      );

  factory ModeloRelatorioSchema.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return ModeloRelatorioSchema.vazio();
    return ModeloRelatorioSchema(
      cabecalho: SecaoQuadroConfig.fromJson((json['cabecalho'] as Map?)?.cast<String, dynamic>() ?? const {}),
      informacoesIniciais:
          InformacoesIniciaisConfig.fromJson((json['informacoes_iniciais'] as Map?)?.cast<String, dynamic>() ?? const {}),
      referencial: ReferencialConfig.fromJson((json['referencial'] as Map?)?.cast<String, dynamic>() ?? const {}),
      registros: SecaoQuadroConfig.fromJson((json['registros'] as Map?)?.cast<String, dynamic>() ?? const {}),
      analiseElementos: json['analise_elementos'] != null
          ? SecaoQuadroConfig.fromJson((json['analise_elementos'] as Map).cast<String, dynamic>())
          : const SecaoQuadroConfig(ativo: false, quadro: Quadro(linhas: [])),
      registrosAgrupados:
          RegistrosAgrupadosConfig.fromJson((json['registros_agrupados'] as Map?)?.cast<String, dynamic>() ?? const {}),
      gutSomatorio: GutSomatorioConfig.fromJson((json['gut_somatorio'] as Map?)?.cast<String, dynamic>() ?? const {}),
      galeria: GaleriaConfig.fromJson((json['galeria'] as Map?)?.cast<String, dynamic>() ?? const {}),
      resumo: ResumoConfig.fromJson((json['resumo'] as Map?)?.cast<String, dynamic>() ?? const {}),
      decoracao: DecoracaoGlobalConfig.fromJson((json['decoracao'] as Map?)?.cast<String, dynamic>() ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'cabecalho': cabecalho.toJson(),
        'informacoes_iniciais': informacoesIniciais.toJson(),
        'referencial': referencial.toJson(),
        'registros': registros.toJson(),
        'analise_elementos': analiseElementos.toJson(),
        'registros_agrupados': registrosAgrupados.toJson(),
        'gut_somatorio': gutSomatorio.toJson(),
        'galeria': galeria.toJson(),
        'resumo': resumo.toJson(),
        'decoracao': decoracao.toJson(),
      };

  ModeloRelatorioSchema copyWith({
    SecaoQuadroConfig? cabecalho,
    InformacoesIniciaisConfig? informacoesIniciais,
    ReferencialConfig? referencial,
    SecaoQuadroConfig? registros,
    SecaoQuadroConfig? analiseElementos,
    RegistrosAgrupadosConfig? registrosAgrupados,
    GutSomatorioConfig? gutSomatorio,
    GaleriaConfig? galeria,
    ResumoConfig? resumo,
    DecoracaoGlobalConfig? decoracao,
  }) {
    return ModeloRelatorioSchema(
      cabecalho: cabecalho ?? this.cabecalho,
      informacoesIniciais: informacoesIniciais ?? this.informacoesIniciais,
      referencial: referencial ?? this.referencial,
      registros: registros ?? this.registros,
      analiseElementos: analiseElementos ?? this.analiseElementos,
      registrosAgrupados: registrosAgrupados ?? this.registrosAgrupados,
      gutSomatorio: gutSomatorio ?? this.gutSomatorio,
      galeria: galeria ?? this.galeria,
      resumo: resumo ?? this.resumo,
      decoracao: decoracao ?? this.decoracao,
    );
  }
}

// "GUT — Somatório de risco": duas tabelas independentes, exclusivas da
// Inspeção Visual (única com anomalias/GUT — ver EnsaioModeloConfig.
// suportaGutSomatorio), que somam o GUT (calcularPontuacaoRiscoGut) de todas
// as anomalias agrupando por Estrutura e por Local — reaproveita a
// hierarquia projeto > estruturas > locais > anomalias já usada no resto do
// relatório. Cada uma liga/desliga independentemente (não é um "hierarquia"
// único como em RegistrosAgrupadosConfig porque o usuário pediu as DUAS
// tabelas, não uma escolha entre elas).
class GutSomatorioConfig {
  final bool ativoPorEstrutura;
  final bool ativoPorLocal;

  const GutSomatorioConfig({required this.ativoPorEstrutura, required this.ativoPorLocal});

  factory GutSomatorioConfig.vazio() => const GutSomatorioConfig(ativoPorEstrutura: false, ativoPorLocal: false);

  factory GutSomatorioConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return GutSomatorioConfig.vazio();
    return GutSomatorioConfig(
      ativoPorEstrutura: json['ativo_por_estrutura'] as bool? ?? false,
      ativoPorLocal: json['ativo_por_local'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'ativo_por_estrutura': ativoPorEstrutura, 'ativo_por_local': ativoPorLocal};

  GutSomatorioConfig copyWith({bool? ativoPorEstrutura, bool? ativoPorLocal}) {
    return GutSomatorioConfig(
      ativoPorEstrutura: ativoPorEstrutura ?? this.ativoPorEstrutura,
      ativoPorLocal: ativoPorLocal ?? this.ativoPorLocal,
    );
  }
}

enum EspessuraBorda { fina, media, grossa }

extension EspessuraBordaX on EspessuraBorda {
  double get largura {
    switch (this) {
      case EspessuraBorda.fina:
        return 1;
      case EspessuraBorda.media:
        return 2;
      case EspessuraBorda.grossa:
        return 3.5;
    }
  }

  String get rotulo {
    switch (this) {
      case EspessuraBorda.fina:
        return 'Fina';
      case EspessuraBorda.media:
        return 'Média';
      case EspessuraBorda.grossa:
        return 'Grossa';
    }
  }

  static EspessuraBorda fromChave(String chave) =>
      EspessuraBorda.values.firstWhere((e) => e.name == chave, orElse: () => EspessuraBorda.fina);
}

enum AlinhamentoTitulo { esquerda, centro, direita, justificado }

extension AlinhamentoTituloX on AlinhamentoTitulo {
  String get rotulo {
    switch (this) {
      case AlinhamentoTitulo.esquerda:
        return 'Esquerda';
      case AlinhamentoTitulo.centro:
        return 'Centro';
      case AlinhamentoTitulo.direita:
        return 'Direita';
      case AlinhamentoTitulo.justificado:
        return 'Justificado';
    }
  }

  static AlinhamentoTitulo fromChave(String chave) =>
      AlinhamentoTitulo.values.firstWhere((a) => a.name == chave, orElse: () => AlinhamentoTitulo.esquerda);
}

enum PosicaoTituloCampo { lado, acima }

extension PosicaoTituloCampoX on PosicaoTituloCampo {
  String get rotulo {
    switch (this) {
      case PosicaoTituloCampo.lado:
        return 'Do lado';
      case PosicaoTituloCampo.acima:
        return 'Acima';
    }
  }

  static PosicaoTituloCampo fromChave(String chave) =>
      PosicaoTituloCampo.values.firstWhere((p) => p.name == chave, orElse: () => PosicaoTituloCampo.lado);
}

// Decoração da "tabela" (Cabeçalho/Informações Iniciais/Registros): borda das
// células, se/como os títulos de cada seção aparecem antes das informações, e
// se/onde o rótulo de cada campo de texto aparece (ex: "GUT: 45").
// É uma configuração única, aplicada a todos os quadros do modelo.
class DecoracaoGlobalConfig {
  final bool bordaAtiva;
  final EspessuraBorda bordaEspessura;
  final String bordaCor;
  final bool mostrarTitulos;
  final AlinhamentoTitulo alinhamentoTitulo;
  final bool mostrarTituloCampos;
  final PosicaoTituloCampo posicaoTituloCampo;
  final double tamanhoFonteTitulo;
  final double tamanhoFonteRotulo;
  final double tamanhoFonteValor;

  const DecoracaoGlobalConfig({
    required this.bordaAtiva,
    required this.bordaEspessura,
    required this.bordaCor,
    required this.mostrarTitulos,
    required this.alinhamentoTitulo,
    required this.mostrarTituloCampos,
    required this.posicaoTituloCampo,
    required this.tamanhoFonteTitulo,
    required this.tamanhoFonteRotulo,
    required this.tamanhoFonteValor,
  });

  factory DecoracaoGlobalConfig.vazio() => const DecoracaoGlobalConfig(
        bordaAtiva: false,
        bordaEspessura: EspessuraBorda.fina,
        bordaCor: 'cinza',
        mostrarTitulos: true,
        alinhamentoTitulo: AlinhamentoTitulo.esquerda,
        mostrarTituloCampos: false,
        posicaoTituloCampo: PosicaoTituloCampo.lado,
        tamanhoFonteTitulo: 14,
        tamanhoFonteRotulo: 12,
        tamanhoFonteValor: 13,
      );

  factory DecoracaoGlobalConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return DecoracaoGlobalConfig.vazio();
    return DecoracaoGlobalConfig(
      bordaAtiva: json['borda_ativa'] as bool? ?? false,
      bordaEspessura: EspessuraBordaX.fromChave(json['borda_espessura']?.toString() ?? 'fina'),
      bordaCor: json['borda_cor']?.toString() ?? 'cinza',
      mostrarTitulos: json['mostrar_titulos'] as bool? ?? true,
      alinhamentoTitulo: AlinhamentoTituloX.fromChave(json['alinhamento_titulo']?.toString() ?? 'esquerda'),
      mostrarTituloCampos: json['mostrar_titulo_campos'] as bool? ?? false,
      posicaoTituloCampo: PosicaoTituloCampoX.fromChave(json['posicao_titulo_campo']?.toString() ?? 'lado'),
      tamanhoFonteTitulo: (json['tamanho_fonte_titulo'] as num?)?.toDouble() ?? 14,
      tamanhoFonteRotulo: (json['tamanho_fonte_rotulo'] as num?)?.toDouble() ?? 12,
      tamanhoFonteValor: (json['tamanho_fonte_valor'] as num?)?.toDouble() ?? 13,
    );
  }

  Map<String, dynamic> toJson() => {
        'borda_ativa': bordaAtiva,
        'borda_espessura': bordaEspessura.name,
        'borda_cor': bordaCor,
        'mostrar_titulos': mostrarTitulos,
        'alinhamento_titulo': alinhamentoTitulo.name,
        'mostrar_titulo_campos': mostrarTituloCampos,
        'posicao_titulo_campo': posicaoTituloCampo.name,
        'tamanho_fonte_titulo': tamanhoFonteTitulo,
        'tamanho_fonte_rotulo': tamanhoFonteRotulo,
        'tamanho_fonte_valor': tamanhoFonteValor,
      };

  DecoracaoGlobalConfig copyWith({
    bool? bordaAtiva,
    EspessuraBorda? bordaEspessura,
    String? bordaCor,
    bool? mostrarTitulos,
    AlinhamentoTitulo? alinhamentoTitulo,
    bool? mostrarTituloCampos,
    PosicaoTituloCampo? posicaoTituloCampo,
    double? tamanhoFonteTitulo,
    double? tamanhoFonteRotulo,
    double? tamanhoFonteValor,
  }) {
    return DecoracaoGlobalConfig(
      bordaAtiva: bordaAtiva ?? this.bordaAtiva,
      bordaEspessura: bordaEspessura ?? this.bordaEspessura,
      bordaCor: bordaCor ?? this.bordaCor,
      mostrarTitulos: mostrarTitulos ?? this.mostrarTitulos,
      alinhamentoTitulo: alinhamentoTitulo ?? this.alinhamentoTitulo,
      mostrarTituloCampos: mostrarTituloCampos ?? this.mostrarTituloCampos,
      posicaoTituloCampo: posicaoTituloCampo ?? this.posicaoTituloCampo,
      tamanhoFonteTitulo: tamanhoFonteTitulo ?? this.tamanhoFonteTitulo,
      tamanhoFonteRotulo: tamanhoFonteRotulo ?? this.tamanhoFonteRotulo,
      tamanhoFonteValor: tamanhoFonteValor ?? this.tamanhoFonteValor,
    );
  }
}

// Seção montada com o editor de Quadro (Cabeçalho e Registros).
class SecaoQuadroConfig {
  final bool ativo;
  final Quadro quadro;
  const SecaoQuadroConfig({required this.ativo, required this.quadro});

  factory SecaoQuadroConfig.fromJson(Map<String, dynamic> json) {
    return SecaoQuadroConfig(
      ativo: json['ativo'] as bool? ?? true,
      quadro: json['quadro'] != null ? Quadro.fromJson((json['quadro'] as Map).cast<String, dynamic>()) : const Quadro(linhas: []),
    );
  }

  Map<String, dynamic> toJson() => {'ativo': ativo, 'quadro': quadro.toJson()};

  SecaoQuadroConfig copyWith({bool? ativo, Quadro? quadro}) =>
      SecaoQuadroConfig(ativo: ativo ?? this.ativo, quadro: quadro ?? this.quadro);
}

// "Informações iniciais": liga/desliga da seção + 3 blocos de repetição
// fixos, cada um com seu próprio Quadro (equipe do projeto, empresas
// participantes do projeto, estruturas do projeto).
class InformacoesIniciaisConfig {
  final bool ativo;
  final Quadro equipe;
  final Quadro empresas;
  final Quadro estruturas;
  final Quadro locais;

  const InformacoesIniciaisConfig({
    required this.ativo,
    required this.equipe,
    required this.empresas,
    required this.estruturas,
    required this.locais,
  });

  factory InformacoesIniciaisConfig.vazio() => const InformacoesIniciaisConfig(
        ativo: true,
        equipe: Quadro(linhas: []),
        empresas: Quadro(linhas: []),
        estruturas: Quadro(linhas: []),
        locais: Quadro(linhas: []),
      );

  factory InformacoesIniciaisConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return InformacoesIniciaisConfig.vazio();
    Quadro quadroDe(String chave) =>
        json[chave] != null ? Quadro.fromJson((json[chave] as Map).cast<String, dynamic>()) : const Quadro(linhas: []);
    return InformacoesIniciaisConfig(
      ativo: json['ativo'] as bool? ?? true,
      equipe: quadroDe('equipe'),
      empresas: quadroDe('empresas'),
      estruturas: quadroDe('estruturas'),
      locais: quadroDe('locais'),
    );
  }

  Map<String, dynamic> toJson() => {
        'ativo': ativo,
        'equipe': equipe.toJson(),
        'empresas': empresas.toJson(),
        'estruturas': estruturas.toJson(),
        'locais': locais.toJson(),
      };

  InformacoesIniciaisConfig copyWith({bool? ativo, Quadro? equipe, Quadro? empresas, Quadro? estruturas, Quadro? locais}) {
    return InformacoesIniciaisConfig(
      ativo: ativo ?? this.ativo,
      equipe: equipe ?? this.equipe,
      empresas: empresas ?? this.empresas,
      estruturas: estruturas ?? this.estruturas,
      locais: locais ?? this.locais,
    );
  }

  InformacoesIniciaisConfig normalizado() => InformacoesIniciaisConfig(
        ativo: ativo,
        equipe: equipe.normalizado(),
        empresas: empresas.normalizado(),
        estruturas: estruturas.normalizado(),
        locais: locais.normalizado(),
      );
}

// Um bloco da seção "Referencial": vinculado a um catálogo de campos
// personalizáveis (ex: "Tipos de estrutura"), com seu próprio Quadro pra
// escolher quais campos daquele catálogo aparecem e como.
class ReferencialBlocoConfig {
  final String id;
  final String catalogo; // chave de CatalogoReferencial (ex: 'tipos_estrutura')
  final Quadro quadro;

  const ReferencialBlocoConfig({required this.id, required this.catalogo, required this.quadro});

  factory ReferencialBlocoConfig.fromJson(Map<String, dynamic> json) {
    return ReferencialBlocoConfig(
      id: json['id']?.toString() ?? gerarIdQuadro(),
      catalogo: json['catalogo']?.toString() ?? '',
      quadro: json['quadro'] != null ? Quadro.fromJson((json['quadro'] as Map).cast<String, dynamic>()) : const Quadro(linhas: []),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'catalogo': catalogo, 'quadro': quadro.toJson()};

  ReferencialBlocoConfig copyWith({Quadro? quadro}) => ReferencialBlocoConfig(id: id, catalogo: catalogo, quadro: quadro ?? this.quadro);
}

// "Referencial": liga/desliga da seção + lista livre de blocos, cada um
// vinculado a um catálogo de campos personalizáveis (Estrutura/Local/
// Elemento/Inspeção Visual e GUT). Mostra só os itens de cada catálogo
// realmente usados nos dados deste relatório — funciona como um glossário.
class ReferencialConfig {
  final bool ativo;
  final List<ReferencialBlocoConfig> blocos;

  const ReferencialConfig({required this.ativo, required this.blocos});

  factory ReferencialConfig.vazio() => const ReferencialConfig(ativo: true, blocos: []);

  factory ReferencialConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return ReferencialConfig.vazio();
    final blocosJson = json['blocos'] as List? ?? const [];
    return ReferencialConfig(
      ativo: json['ativo'] as bool? ?? true,
      blocos: blocosJson.map((b) => ReferencialBlocoConfig.fromJson((b as Map).cast<String, dynamic>())).toList(),
    );
  }

  Map<String, dynamic> toJson() => {'ativo': ativo, 'blocos': blocos.map((b) => b.toJson()).toList()};

  ReferencialConfig copyWith({bool? ativo, List<ReferencialBlocoConfig>? blocos}) =>
      ReferencialConfig(ativo: ativo ?? this.ativo, blocos: blocos ?? this.blocos);

  ReferencialConfig normalizado() =>
      ReferencialConfig(ativo: ativo, blocos: blocos.map((b) => b.copyWith(quadro: b.quadro.normalizado())).toList());
}

// Como agrupar "Registros agrupados" (só faz sentido pra ensaios que
// suportam essa seção, ver EnsaioModeloConfig.suportaRegistrosAgrupados).
enum HierarquiaAgrupamento { localTipoElemento, local, tipoElemento }

extension HierarquiaAgrupamentoX on HierarquiaAgrupamento {
  String get rotulo {
    switch (this) {
      case HierarquiaAgrupamento.localTipoElemento:
        return 'Local + Tipo de elemento';
      case HierarquiaAgrupamento.local:
        return 'Só por Local';
      case HierarquiaAgrupamento.tipoElemento:
        return 'Só por Tipo de elemento';
    }
  }

  static HierarquiaAgrupamento fromChave(String chave) =>
      HierarquiaAgrupamento.values.firstWhere((h) => h.name == chave, orElse: () => HierarquiaAgrupamento.localTipoElemento);
}

// Chaves fixas dos 4 gráficos-resumo disponíveis pra seção "Registros
// agrupados" (ver RelatorioChartRenderer) — cada um resume TODOS os grupos
// de uma vez (uma curva ou um boxplot com uma série por grupo), então
// funcionam como campos do tipo imagem dentro de um Quadro normal: o
// usuário monta linhas/divisões e escolhe qual gráfico entra em cada slot,
// igual a qualquer outra seção com Quadro.
const chaveGraficoAvancoFrente = 'avanco_frente';
const chaveGraficoProbabilidade = 'probabilidade';
const chaveGraficoBoxplotElemento = 'boxplot_elemento';
const chaveGraficoBoxplotLocal = 'boxplot_local';
// Variantes com uma curva por grupo (em vez de uma curva só, com todos os
// pontos agrupados) — mesma ideia do boxplot por elemento/local.
const chaveGraficoAvancoFrentePorElemento = 'avanco_frente_por_elemento';
const chaveGraficoAvancoFrentePorLocal = 'avanco_frente_por_local';
const chaveGraficoProbabilidadePorElemento = 'probabilidade_por_elemento';
const chaveGraficoProbabilidadePorLocal = 'probabilidade_por_local';
// Resistividade: barra com a resistividade média por grupo, com faixas de
// fundo coloridas indicando a zona de risco de corrosão (ver
// ResistividadeModeloReportData e a tela de análise global já existente).
const chaveGraficoDistribuicaoRiscoElemento = 'distribuicao_risco_por_elemento';
const chaveGraficoDistribuicaoRiscoLocal = 'distribuicao_risco_por_local';
// Arrancamento em Argamassa: barra com a tensão média por ELEMENTO
// individual (não pooled pela hierarquia — sempre um elemento por barra,
// igual à aba "Gráficos" de `analise_todos_arrancamento_screen.dart`),
// segmentada proporcionalmente por tipo de ruptura. E um boxplot que também
// não agrupa pela hierarquia: uma caixa por elemento específico, colorida
// por tipo de elemento (igual à aba "Estatísticas" da mesma tela) — diferente
// de `chaveGraficoBoxplotElemento`, que agrupa TODOS os elementos do mesmo
// tipo numa caixa só.
const chaveGraficoBarraTensaoElementos = 'barra_tensao_elementos';
const chaveGraficoBoxplotElementosEspecificos = 'boxplot_elementos_especificos';
// Esclerometria: barra com a Média Q por PONTO DE ENSAIO individual (não
// agrupada pela hierarquia — sempre um ponto por barra, mesma ideia da tela
// de análise global já existente); reaproveita `chaveGraficoBoxplotElemento`/
// `chaveGraficoBoxplotLocal` (esses sim agrupados pela hierarquia) pro
// boxplot por elemento/local.
const chaveGraficoBarraPontosEsclerometria = 'barra_pontos_esclerometria';
// Ultrassonografia: nenhum desses agrupa pela hierarquia — são a MESMA
// análise global já existente em `AnaliseTodosUltrassomScreen` (barra por
// ELEMENTO, boxplot por elemento colorido por Local), reaproveitada como
// gráfico-resumo do relatório. Longitudinal/Transversal são pulsos
// separados (escalas diferentes, não fazem sentido juntos numa caixa só);
// Ed/Resistência/fck só existem pros elementos com as duas ondas.
const chaveGraficoBarraLongitudinal = 'barra_longitudinal_us';
const chaveGraficoBarraTransversal = 'barra_transversal_us';
const chaveGraficoBarraResistencia = 'barra_resistencia_us';
const chaveGraficoBarraModuloElasticidade = 'barra_modulo_elasticidade_us';
const chaveGraficoDistribuicaoFck = 'distribuicao_fck_us';
const chaveGraficoBoxplotLongitudinal = 'boxplot_longitudinal_us';
const chaveGraficoBoxplotTransversal = 'boxplot_transversal_us';
// Tração em Chumbador: um único boxplot com uma caixa por combinação
// Local + Tipo de elemento (não dois boxplots separados por dimensão,
// diferente de chaveGraficoBoxplotElemento/Local) — pedido explícito do
// usuário ("boxplot único por local e tipo de elemento").
const chaveGraficoBoxplotLocalTipoChumbador = 'boxplot_local_tipo_chumbador';

// Líquido penetrante: barras empilhadas por status (Aprovado / Reprovado /
// Cabe análise), uma barra por combinação Local + Tipo de elemento — o
// resultado do ensaio é contagem, não um valor numérico.
const chaveGraficoStatusLocalTipoLP = 'barras_status_local_tipo_lp';

// Extração e Rompimento de Testemunho: barra com a resistência corrigida
// média (e o fck estimado) por Tipo de elemento / por Local — mesmo padrão
// de chave dupla de outros ensaios (ex: chaveGraficoBoxplotElemento/Local).
const chaveGraficoResistenciaElementoExt = 'resistencia_por_elemento_ext';
const chaveGraficoResistenciaLocalExt = 'resistencia_por_local_ext';
const chaveGraficoFckElementoExt = 'fck_por_elemento_ext';
const chaveGraficoFckLocalExt = 'fck_por_local_ext';

// "Registros agrupados": uma tabela estatística com uma linha por grupo
// (conforme `hierarquia`) + um Quadro livre pros até 4 gráficos-resumo.
class RegistrosAgrupadosConfig {
  final bool ativo;
  final HierarquiaAgrupamento hierarquia;
  final List<ResumoColuna> colunas;
  final Quadro graficos;

  const RegistrosAgrupadosConfig({
    required this.ativo,
    required this.hierarquia,
    required this.colunas,
    required this.graficos,
  });

  factory RegistrosAgrupadosConfig.vazio() => const RegistrosAgrupadosConfig(
      ativo: false, hierarquia: HierarquiaAgrupamento.localTipoElemento, colunas: [], graficos: Quadro(linhas: []));

  factory RegistrosAgrupadosConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return RegistrosAgrupadosConfig.vazio();
    final colunasJson = json['colunas'] as List? ?? const [];
    return RegistrosAgrupadosConfig(
      ativo: json['ativo'] as bool? ?? false,
      hierarquia: HierarquiaAgrupamentoX.fromChave(json['hierarquia']?.toString() ?? 'localTipoElemento'),
      colunas: colunasJson.map((c) => ResumoColuna.fromJson((c as Map).cast<String, dynamic>())).toList(),
      graficos: json['graficos'] != null ? Quadro.fromJson((json['graficos'] as Map).cast<String, dynamic>()) : const Quadro(linhas: []),
    );
  }

  Map<String, dynamic> toJson() => {
        'ativo': ativo,
        'hierarquia': hierarquia.name,
        'colunas': colunas.map((c) => c.toJson()).toList(),
        'graficos': graficos.toJson(),
      };

  RegistrosAgrupadosConfig copyWith({
    bool? ativo,
    HierarquiaAgrupamento? hierarquia,
    List<ResumoColuna>? colunas,
    Quadro? graficos,
  }) {
    return RegistrosAgrupadosConfig(
      ativo: ativo ?? this.ativo,
      hierarquia: hierarquia ?? this.hierarquia,
      colunas: colunas ?? this.colunas,
      graficos: graficos ?? this.graficos,
    );
  }

  RegistrosAgrupadosConfig normalizado() => copyWith(graficos: graficos.normalizado());
}

class GaleriaConfig {
  final bool ativo;
  final int colunas;
  final bool mostrarDescricao;
  final double alturaImagem;
  final AjusteImagem ajusteImagem;

  const GaleriaConfig({
    required this.ativo,
    required this.colunas,
    required this.mostrarDescricao,
    required this.alturaImagem,
    required this.ajusteImagem,
  });

  factory GaleriaConfig.vazio() => const GaleriaConfig(
        ativo: true,
        colunas: 4,
        mostrarDescricao: true,
        alturaImagem: 140,
        ajusteImagem: AjusteImagem.cobrir,
      );

  factory GaleriaConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return GaleriaConfig.vazio();
    return GaleriaConfig(
      ativo: json['ativo'] as bool? ?? true,
      colunas: (json['colunas'] as num?)?.toInt() ?? 4,
      mostrarDescricao: json['mostrar_descricao'] as bool? ?? true,
      alturaImagem: (json['altura_imagem'] as num?)?.toDouble() ?? 140,
      ajusteImagem: AjusteImagemX.fromChave(json['ajuste_imagem']?.toString() ?? 'cobrir'),
    );
  }

  Map<String, dynamic> toJson() => {
        'ativo': ativo,
        'colunas': colunas,
        'mostrar_descricao': mostrarDescricao,
        'altura_imagem': alturaImagem,
        'ajuste_imagem': ajusteImagem.name,
      };

  GaleriaConfig copyWith({bool? ativo, int? colunas, bool? mostrarDescricao, double? alturaImagem, AjusteImagem? ajusteImagem}) {
    return GaleriaConfig(
      ativo: ativo ?? this.ativo,
      colunas: colunas ?? this.colunas,
      mostrarDescricao: mostrarDescricao ?? this.mostrarDescricao,
      alturaImagem: alturaImagem ?? this.alturaImagem,
      ajusteImagem: ajusteImagem ?? this.ajusteImagem,
    );
  }
}

// Uma coluna calculada multiplica/soma/subtrai/divide os valores (já
// formatados, ex: "92,4 kN") de 2+ colunas catalogadas, em sequência da
// esquerda pra direita, podendo misturar operadores entre pares consecutivos
// — ex: G × U × T = GUT, ou A × B + C — e opcionalmente troca o número
// resultante por um texto, conforme a primeira `RegraColunaCalculada` (em
// ordem) que bater, com `textoPadrao` como "senão" (ou o próprio número, se
// `textoPadrao` for nulo).
enum TipoResumoColuna { catalogo, calculada }

enum OperadorFormula { multiplicar, somar, subtrair, dividir }

extension OperadorFormulaX on OperadorFormula {
  String get simbolo {
    switch (this) {
      case OperadorFormula.multiplicar:
        return '×';
      case OperadorFormula.somar:
        return '+';
      case OperadorFormula.subtrair:
        return '−';
      case OperadorFormula.dividir:
        return '÷';
    }
  }

  String get rotulo {
    switch (this) {
      case OperadorFormula.multiplicar:
        return 'Multiplicar';
      case OperadorFormula.somar:
        return 'Somar';
      case OperadorFormula.subtrair:
        return 'Subtrair';
      case OperadorFormula.dividir:
        return 'Dividir';
    }
  }

  static OperadorFormula fromChave(String chave) =>
      OperadorFormula.values.firstWhere((o) => o.name == chave, orElse: () => OperadorFormula.multiplicar);

  double aplicar(double a, double b) {
    switch (this) {
      case OperadorFormula.multiplicar:
        return a * b;
      case OperadorFormula.somar:
        return a + b;
      case OperadorFormula.subtrair:
        return a - b;
      case OperadorFormula.dividir:
        return b == 0 ? 0 : a / b;
    }
  }
}

// Regra "se [resultado] operador valorComparacao então texto = textoResultado"
// — reaproveita `OperadorCondicional` (maiorQue/menorQue/igual/diferente; só
// não expõe "contém" no editor, não faz sentido pra número).
class RegraColunaCalculada {
  final OperadorCondicional operador;
  final double valorComparacao;
  final String textoResultado;

  const RegraColunaCalculada({required this.operador, required this.valorComparacao, required this.textoResultado});

  factory RegraColunaCalculada.fromJson(Map<String, dynamic> json) => RegraColunaCalculada(
        operador: OperadorCondicionalX.fromChave(json['operador']?.toString() ?? 'maiorQue'),
        valorComparacao: double.tryParse(json['valor_comparacao']?.toString() ?? '') ?? 0,
        textoResultado: json['texto_resultado']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'operador': operador.name,
        'valor_comparacao': valorComparacao,
        'texto_resultado': textoResultado,
      };
}

// Numeraliza um valor categórico (texto) pra poder usar campos como CAA
// ("I".."IV") ou Classe do risco dentro de uma fórmula — ex: CAA "II" vale
// 40. `padrao` é usado quando o valor da linha não bate com nenhuma regra.
class RegraNumeralizacao {
  final String valor;
  final double numero;

  const RegraNumeralizacao({required this.valor, required this.numero});

  factory RegraNumeralizacao.fromJson(Map<String, dynamic> json) => RegraNumeralizacao(
        valor: json['valor']?.toString() ?? '',
        numero: double.tryParse(json['numero']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {'valor': valor, 'numero': numero};
}

class NumeralizacaoCampo {
  final String campo; // chave de CampoCatalogo
  final List<RegraNumeralizacao> regras;
  final double padrao;

  const NumeralizacaoCampo({required this.campo, this.regras = const [], this.padrao = 0});

  factory NumeralizacaoCampo.fromJson(Map<String, dynamic> json) => NumeralizacaoCampo(
        campo: json['campo']?.toString() ?? '',
        regras: (json['regras'] as List? ?? const [])
            .map((r) => RegraNumeralizacao.fromJson((r as Map).cast<String, dynamic>()))
            .toList(),
        padrao: double.tryParse(json['padrao']?.toString() ?? '') ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'campo': campo,
        'regras': regras.map((r) => r.toJson()).toList(),
        'padrao': padrao,
      };

  double resolver(String? valorBruto) {
    final valor = (valorBruto ?? '').trim().toLowerCase();
    for (final r in regras) {
      if (r.valor.trim().toLowerCase() == valor) return r.numero;
    }
    return padrao;
  }
}

class ResumoColuna {
  final String id;
  final String rotulo;
  final String? campoVinculado; // null = coluna "Quantidade" (contagem) OU calculada
  final String? tabela; // 'projeto' | 'estrutura' | 'registro' | 'anomalia' | null (Quantidade/calculada)

  // ---- só preenchidos quando tipo == calculada ----
  final TipoResumoColuna tipo;
  final List<String> operandos; // chaves de CampoCatalogo, na ordem da fórmula
  final List<OperadorFormula> operadores; // operadores[i] liga operandos[i] a operandos[i+1] — length == operandos.length - 1
  final List<NumeralizacaoCampo> numeralizacoes; // um por operando categórico (ver camposCategoricosParaFormula)
  final List<RegraColunaCalculada> regras;
  final String? textoPadrao; // "senão" — nulo/vazio = mostra o número calculado
  final int casasDecimais;

  const ResumoColuna({
    required this.id,
    required this.rotulo,
    this.campoVinculado,
    this.tabela,
    this.tipo = TipoResumoColuna.catalogo,
    this.operandos = const [],
    this.operadores = const [],
    this.numeralizacoes = const [],
    this.regras = const [],
    this.textoPadrao,
    this.casasDecimais = 2,
  });

  bool get ehCalculada => tipo == TipoResumoColuna.calculada;

  factory ResumoColuna.fromJson(Map<String, dynamic> json) {
    final operandos = (json['operandos'] as List? ?? const []).map((e) => e.toString()).toList();
    List<OperadorFormula> operadores;
    if (json['operadores'] is List) {
      operadores = (json['operadores'] as List).map((e) => OperadorFormulaX.fromChave(e.toString())).toList();
    } else if (json['operador'] != null) {
      // Compat: schema antigo tinha um único `operador` aplicado entre todos os operandos.
      final unico = OperadorFormulaX.fromChave(json['operador'].toString());
      operadores = List.filled(operandos.isEmpty ? 0 : operandos.length - 1, unico);
    } else {
      operadores = const [];
    }
    return ResumoColuna(
      id: json['id']?.toString() ?? '',
      rotulo: json['rotulo']?.toString() ?? '',
      campoVinculado: json['campo_vinculado']?.toString(),
      tabela: json['tabela']?.toString(),
      tipo: json['tipo']?.toString() == 'calculada' ? TipoResumoColuna.calculada : TipoResumoColuna.catalogo,
      operandos: operandos,
      operadores: operadores,
      numeralizacoes: (json['numeralizacoes'] as List? ?? const [])
          .map((n) => NumeralizacaoCampo.fromJson((n as Map).cast<String, dynamic>()))
          .toList(),
      regras: (json['regras'] as List? ?? const []).map((r) => RegraColunaCalculada.fromJson((r as Map).cast<String, dynamic>())).toList(),
      textoPadrao: json['texto_padrao']?.toString(),
      casasDecimais: (json['casas_decimais'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rotulo': rotulo,
        'campo_vinculado': campoVinculado,
        'tabela': tabela,
        if (ehCalculada) 'tipo': 'calculada',
        if (ehCalculada) 'operandos': operandos,
        if (ehCalculada) 'operadores': operadores.map((o) => o.name).toList(),
        if (ehCalculada) 'numeralizacoes': numeralizacoes.map((n) => n.toJson()).toList(),
        if (ehCalculada) 'regras': regras.map((r) => r.toJson()).toList(),
        if (ehCalculada && textoPadrao != null) 'texto_padrao': textoPadrao,
        if (ehCalculada) 'casas_decimais': casasDecimais,
      };
}

class ResumoConfig {
  final bool ativo;
  final List<ResumoColuna> colunas;

  const ResumoConfig({required this.ativo, required this.colunas});

  // Sem colunas padrão: os campos disponíveis (e suas chaves) variam por
  // tipo de ensaio (ver EnsaioModeloConfig.tabelasResumo) — um padrão fixo
  // aqui (ex: campoVinculado 'local') só faria sentido pra Inspeção Visual e
  // ficaria em branco pra qualquer outro ensaio. O usuário escolhe as
  // colunas pelo próprio catálogo certo na hora de configurar o modelo.
  factory ResumoConfig.vazio() => const ResumoConfig(ativo: true, colunas: []);

  factory ResumoConfig.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) return ResumoConfig.vazio();
    final colunasJson = json['colunas'] as List? ?? const [];
    return ResumoConfig(
      ativo: json['ativo'] as bool? ?? true,
      colunas: colunasJson.map((c) => ResumoColuna.fromJson((c as Map).cast<String, dynamic>())).toList(),
    );
  }

  Map<String, dynamic> toJson() => {'ativo': ativo, 'colunas': colunas.map((c) => c.toJson()).toList()};

  ResumoConfig copyWith({bool? ativo, List<ResumoColuna>? colunas}) {
    return ResumoConfig(ativo: ativo ?? this.ativo, colunas: colunas ?? this.colunas);
  }
}
