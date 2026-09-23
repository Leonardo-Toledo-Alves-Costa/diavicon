import 'dart:convert';

/// Uma entrada da fórmula: o alias usado na expressão (`V`, `R`) ligado a um
/// campo concreto do catálogo de BI, com a estatística que o resolve.
///
/// A junção entre ensaios diferentes é sempre por ELEMENTO estrutural (é a
/// chave de `BiDataPoint`), então cada entrada vira um número por elemento —
/// tipicamente a média das leituras daquele ensaio naquele elemento. Não há
/// pareamento leitura-a-leitura: num mesmo elemento as 12 leituras de
/// ultrassom e os 16 índices esclerométricos não são medidos nos mesmos
/// pontos físicos.
class EntradaVariavelBi {
  /// Nome usado dentro da expressão. Precisa ser um identificador válido.
  final String alias;

  /// Chave da fonte no catálogo (ex.: 'ultrassom').
  final String fonte;

  /// Chave do campo dentro da fonte (ex.: 'velocidade_longitudinal').
  final String campo;

  /// Nome da estatística (`media`, `desvioPadrao`, `coefVariacao`). Nulo pros
  /// campos brutos, que não têm segundo seletor.
  final String? estatistica;

  const EntradaVariavelBi({
    required this.alias,
    required this.fonte,
    required this.campo,
    this.estatistica,
  });

  factory EntradaVariavelBi.fromMap(Map<String, dynamic> m) => EntradaVariavelBi(
        alias: m['alias']?.toString() ?? '',
        fonte: m['fonte']?.toString() ?? '',
        campo: m['campo']?.toString() ?? '',
        estatistica: m['estatistica']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'alias': alias,
        'fonte': fonte,
        'campo': campo,
        if (estatistica != null) 'estatistica': estatistica,
      };
}

/// Variável derivada de uma ou mais fontes de ensaio, definida pela empresa.
///
/// As variáveis da empresa DIAVICON valem como padrão para todas as demais:
/// aparecem somente-leitura e são duplicadas pra empresa quando alguém quer
/// alterá-las (mesmo mecanismo de `dashboard_modelos`, com a linhagem em
/// [variavelOrigemId]).
class VariavelBiModel {
  final String id;
  final String empresaId;
  final String? criadoPor;
  final String nome;
  final String? unidade;
  final String? descricao;

  /// Expressão avaliada com os aliases de [entradas] e as chaves de
  /// [parametros] como variáveis. Ex.: `a * pow(V, b) * pow(R, c)`.
  final String expressao;
  final List<EntradaVariavelBi> entradas;

  /// Coeficientes de calibração, separados da expressão de propósito: a
  /// expressão é a norma, os parâmetros são a calibração da obra. Embutir os
  /// números na fórmula transformaria cada recalibração numa fórmula nova.
  final Map<String, double> parametros;

  final String? referencia;

  /// Faixa plausível pro resultado. Fora dela o valor não é descartado — é
  /// sinalizado, porque o modo de falha comum (unidade ou coeficiente
  /// trocado) produz número válido, só que absurdo.
  final double? valorMin;
  final double? valorMax;

  final String? variavelOrigemId;

  const VariavelBiModel({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.expressao,
    required this.entradas,
    this.criadoPor,
    this.unidade,
    this.descricao,
    this.parametros = const {},
    this.referencia,
    this.valorMin,
    this.valorMax,
    this.variavelOrigemId,
  });

  /// As fontes de ensaio que a variável precisa. Mais de uma = multi-ensaio
  /// (correlação); uma só = métrica calculada. É a mesma entidade — o que
  /// muda é só quantas fontes a expressão toca.
  Set<String> get fontesNecessarias => entradas.map((e) => e.fonte).toSet();

  bool get ehMultiEnsaio => fontesNecessarias.length > 1;

  factory VariavelBiModel.fromMap(Map<String, dynamic> m) => VariavelBiModel(
        id: m['id'].toString(),
        empresaId: m['empresa_id'].toString(),
        criadoPor: m['criado_por']?.toString(),
        nome: m['nome']?.toString() ?? '',
        unidade: m['unidade']?.toString(),
        descricao: m['descricao']?.toString(),
        expressao: m['expressao']?.toString() ?? '',
        entradas: _lista(m['entradas']).map(EntradaVariavelBi.fromMap).toList(),
        parametros: _parametros(m['parametros']),
        referencia: m['referencia']?.toString(),
        valorMin: _double(m['valor_min']),
        valorMax: _double(m['valor_max']),
        variavelOrigemId: m['variavel_origem_id']?.toString(),
      );

  Map<String, dynamic> toMap() => {
        'empresa_id': empresaId,
        if (criadoPor != null) 'criado_por': criadoPor,
        'nome': nome,
        'unidade': unidade,
        'descricao': descricao,
        'expressao': expressao,
        'entradas': entradas.map((e) => e.toMap()).toList(),
        'parametros': parametros,
        'referencia': referencia,
        'valor_min': valorMin,
        'valor_max': valorMax,
        if (variavelOrigemId != null) 'variavel_origem_id': variavelOrigemId,
      };

  // `entradas`/`parametros` nasceram como `text` no Supabase e viram `jsonb`
  // na migration de ajuste — aceitar as duas formas evita que a ordem de
  // aplicação da migration quebre a leitura.
  static List<Map<String, dynamic>> _lista(dynamic valor) {
    final bruto = valor is String ? (valor.isEmpty ? null : jsonDecode(valor)) : valor;
    if (bruto is! List) return const [];
    return bruto.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static Map<String, double> _parametros(dynamic valor) {
    final bruto = valor is String ? (valor.isEmpty ? null : jsonDecode(valor)) : valor;
    if (bruto is! Map) return const {};
    final saida = <String, double>{};
    bruto.forEach((k, v) {
      final n = _double(v);
      if (n != null) saida[k.toString()] = n;
    });
    return saida;
  }

  static double? _double(dynamic v) => v == null ? null : double.tryParse(v.toString());
}
