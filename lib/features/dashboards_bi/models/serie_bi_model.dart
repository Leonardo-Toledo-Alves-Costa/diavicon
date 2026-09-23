import 'package:flutter/material.dart';

import 'campos_bi_catalogo.dart';
import '../utils/cores_bi.dart';

/// De onde vem um valor numérico no dashboard: um campo do catálogo de um
/// ensaio (com a estatística que o resume) OU uma equação (variável
/// derivada, ex.: SonReb).
///
/// É a mesma peça para série de gráfico, coluna de tabela e entrada de
/// badge — por isso uma série pode ser tanto "média da velocidade
/// longitudinal" quanto "resistência estimada SonReb".
class ReferenciaValorBi {
  final String? fonte;
  final String? campo;
  final String? estatistica;

  /// Equação salva nos padrões da empresa.
  final String? variavelId;

  /// Equação embutida (criada "só neste card").
  final Map<String, dynamic>? variavelInline;

  const ReferenciaValorBi({this.fonte, this.campo, this.estatistica, this.variavelId, this.variavelInline});

  bool get ehVariavel => variavelId != null || variavelInline != null;
  bool get valida => ehVariavel || (fonte != null && campo != null);

  /// Rótulo automático, usado quando o usuário não dá nome à série/coluna.
  String rotuloPadrao({String? nomeVariavel}) {
    if (ehVariavel) return nomeVariavel ?? (variavelInline?['nome']?.toString() ?? 'Equação');
    final campoCat = (fonte != null && campo != null) ? buscarCampoBi(fonte!, campo!) : null;
    final base = campoCat?.rotulo ?? campo ?? '';
    final est = estatistica == null
        ? null
        : EstatisticaBi.values.where((e) => e.name == estatistica).firstOrNull?.rotulo;
    return est == null ? base : '$base ($est)';
  }

  String? get unidade {
    if (ehVariavel) return variavelInline?['unidade']?.toString();
    final campoCat = (fonte != null && campo != null) ? buscarCampoBi(fonte!, campo!) : null;
    // Coeficiente de variação é em % seja qual for a unidade do campo.
    if (estatistica == EstatisticaBi.coefVariacao.name) return '%';
    return campoCat?.unidade;
  }

  Map<String, dynamic> toJson() => {
        if (fonte != null) 'fonte': fonte,
        if (campo != null) 'campo': campo,
        if (estatistica != null) 'estatistica': estatistica,
        if (variavelId != null) 'variavelId': variavelId,
        if (variavelInline != null) 'variavelInline': variavelInline,
      };

  factory ReferenciaValorBi.fromJson(Map<String, dynamic> j) => ReferenciaValorBi(
        fonte: j['fonte'] as String?,
        campo: j['campo'] as String?,
        estatistica: j['estatistica'] as String?,
        variavelId: j['variavelId'] as String?,
        variavelInline: (j['variavelInline'] as Map?)?.cast<String, dynamic>(),
      );
}

// ── Gráfico personalizado ──────────────────────────────────────────────────

enum TipoSerieBi {
  barra('Barra'),
  barraEmpilhada('Barra empilhada'),
  // Uma série fatiada por tipo, local, estrutura, categoria ou classificação
  // (ver SerieBi.segmentarPor e segmentacao_bi.dart).
  barraSegmentada('Barra segmentada'),
  linha('Linha');

  final String rotulo;
  const TipoSerieBi(this.rotulo);

  static TipoSerieBi fromChave(String? c) => TipoSerieBi.values.firstWhere((t) => t.name == c, orElse: () => TipoSerieBi.barra);
}

/// Uma série de um gráfico personalizado. Várias séries convivem no mesmo
/// gráfico, cada uma com seu tipo, eixo e cor — inclusive misturando campos
/// de ensaios diferentes e equações.
class SerieBi {
  final String id;
  final String nome;
  final ReferenciaValorBi valor;

  /// 1 = eixo Y da esquerda, 2 = eixo Y da direita. O segundo eixo existe
  /// para grandezas de ordem de grandeza diferente no mesmo gráfico (ex.:
  /// velocidade em m/s e resistividade em kΩ·cm).
  final int eixo;
  final TipoSerieBi tipo;
  final int cor;

  /// Só para [TipoSerieBi.barraSegmentada]: 'tipoElemento', 'local',
  /// 'estrutura', 'categoria' ou 'classificacao:<escala>'.
  final String? segmentarPor;

  const SerieBi({
    required this.id,
    required this.nome,
    required this.valor,
    this.eixo = 1,
    this.tipo = TipoSerieBi.barra,
    this.cor = corPadraoBiInt,
    this.segmentarPor,
  });

  Color get corCor => Color(corBiNormalizada(cor));

  SerieBi copyWith({String? nome, ReferenciaValorBi? valor, int? eixo, TipoSerieBi? tipo, int? cor, String? segmentarPor}) => SerieBi(
        id: id,
        nome: nome ?? this.nome,
        valor: valor ?? this.valor,
        eixo: eixo ?? this.eixo,
        tipo: tipo ?? this.tipo,
        cor: cor ?? this.cor,
        segmentarPor: segmentarPor ?? this.segmentarPor,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'valor': valor.toJson(),
        'eixo': eixo,
        'tipo': tipo.name,
        'cor': cor,
        if (segmentarPor != null) 'segmentarPor': segmentarPor,
      };

  factory SerieBi.fromJson(Map<String, dynamic> j) => SerieBi(
        id: j['id'] as String,
        nome: j['nome'] as String? ?? '',
        valor: ReferenciaValorBi.fromJson(((j['valor'] as Map?) ?? const {}).cast<String, dynamic>()),
        eixo: (j['eixo'] as num?)?.toInt() == 2 ? 2 : 1,
        tipo: TipoSerieBi.fromChave(j['tipo'] as String?),
        cor: (j['cor'] as num?)?.toInt() ?? corPadraoBiInt,
        segmentarPor: j['segmentarPor'] as String?,
      );
}

// ── Tabela ─────────────────────────────────────────────────────────────────

enum OperadorRegraBi {
  maiorQue('>'),
  maiorOuIgual('≥'),
  menorQue('<'),
  menorOuIgual('≤'),
  entre('entre');

  final String simbolo;
  const OperadorRegraBi(this.simbolo);

  static OperadorRegraBi fromChave(String? c) =>
      OperadorRegraBi.values.firstWhere((o) => o.name == c, orElse: () => OperadorRegraBi.maiorQue);
}

/// Regra de cor condicional de uma coluna. Numérica de propósito: as
/// colunas da tabela são sempre números (média, desvio, CV ou equação).
class RegraCorBi {
  final OperadorRegraBi operador;
  final double valor;

  /// Limite superior, só para [OperadorRegraBi.entre] (inclusivo nos dois
  /// lados).
  final double? valor2;
  final int cor;

  const RegraCorBi({required this.operador, required this.valor, this.valor2, required this.cor});

  bool aplica(double v) => switch (operador) {
        OperadorRegraBi.maiorQue => v > valor,
        OperadorRegraBi.maiorOuIgual => v >= valor,
        OperadorRegraBi.menorQue => v < valor,
        OperadorRegraBi.menorOuIgual => v <= valor,
        OperadorRegraBi.entre => valor2 != null && v >= (valor < valor2! ? valor : valor2!) && v <= (valor < valor2! ? valor2! : valor),
      };

  String get descricao => operador == OperadorRegraBi.entre
      ? 'entre ${_fmt(valor)} e ${_fmt(valor2 ?? valor)}'
      : '${operador.simbolo} ${_fmt(valor)}';

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Map<String, dynamic> toJson() => {
        'operador': operador.name,
        'valor': valor,
        if (valor2 != null) 'valor2': valor2,
        'cor': cor,
      };

  factory RegraCorBi.fromJson(Map<String, dynamic> j) => RegraCorBi(
        operador: OperadorRegraBi.fromChave(j['operador'] as String?),
        valor: (j['valor'] as num?)?.toDouble() ?? 0,
        valor2: (j['valor2'] as num?)?.toDouble(),
        cor: (j['cor'] as num?)?.toInt() ?? 0xFFD32F2F,
      );
}

/// Uma coluna da tabela. Título e ordem são do dashboard (não alteram o
/// catálogo nem a equação de origem).
class ColunaTabelaBi {
  final String id;
  final String titulo;
  final ReferenciaValorBi valor;

  /// Avaliadas em ordem; a primeira que casar pinta a célula.
  final List<RegraCorBi> regras;

  const ColunaTabelaBi({required this.id, required this.titulo, required this.valor, this.regras = const []});

  Color? corPara(double? v) {
    if (v == null) return null;
    for (final r in regras) {
      if (r.aplica(v)) return Color(r.cor);
    }
    return null;
  }

  ColunaTabelaBi copyWith({String? titulo, ReferenciaValorBi? valor, List<RegraCorBi>? regras}) => ColunaTabelaBi(
        id: id,
        titulo: titulo ?? this.titulo,
        valor: valor ?? this.valor,
        regras: regras ?? this.regras,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'valor': valor.toJson(),
        'regras': regras.map((r) => r.toJson()).toList(),
      };

  factory ColunaTabelaBi.fromJson(Map<String, dynamic> j) => ColunaTabelaBi(
        id: j['id'] as String,
        titulo: j['titulo'] as String? ?? '',
        valor: ReferenciaValorBi.fromJson(((j['valor'] as Map?) ?? const {}).cast<String, dynamic>()),
        regras: ((j['regras'] as List?) ?? const [])
            .whereType<Map>()
            .map((r) => RegraCorBi.fromJson(r.cast<String, dynamic>()))
            .toList(),
      );
}
