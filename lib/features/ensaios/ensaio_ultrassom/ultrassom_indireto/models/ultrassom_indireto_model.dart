import 'dart:math';

/// Uma leitura (D, velocidade) dentro de um ponto de medição do método
/// indireto — `ponto_ensaio_ultrassom_indireto_leitura`. A velocidade é
/// informada pelo aparelho (igual ao método direto); o tempo de propagação
/// não é uma coluna própria — é derivado (µs) pra alimentar a regressão
/// tempo x distância que dá a velocidade verdadeira do ponto de medição.
class LeituraUltrassomIndiretoModel {
  final String? id;
  final String? idMedicao;
  double distancia; // cm
  double velocidade; // m/s

  LeituraUltrassomIndiretoModel({this.id, this.idMedicao, required this.distancia, required this.velocidade});

  // tempo(s) = distancia(m)/velocidade(m/s) = (distancia/100)/velocidade;
  // tempo(µs) = tempo(s) * 1e6 = distancia * 10000 / velocidade.
  double get tempoMicrossegundos => velocidade <= 0 ? 0 : (distancia * 10000) / velocidade;

  factory LeituraUltrassomIndiretoModel.fromJson(Map<String, dynamic> json) {
    return LeituraUltrassomIndiretoModel(
      id: json['id']?.toString(),
      idMedicao: json['ponto_id']?.toString(),
      distancia: (json['distancia'] as num?)?.toDouble() ?? 0.0,
      velocidade: (json['velocidade'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson(String idMedicao) {
    return {
      if (id != null) 'id': id,
      'ponto_id': idMedicao,
      'distancia': distancia.round(),
      'velocidade': velocidade.round(),
    };
  }
}

// Regressão linear simples (mínimos quadrados) de um conjunto de pontos
// (x, y) — usada pra achar a reta tempo x distância.
({double slope, double intercept, double r2})? _regressaoLinear(List<({double x, double y})> pontos) {
  final n = pontos.length;
  if (n < 2) return null;

  final somaX = pontos.fold(0.0, (a, p) => a + p.x);
  final somaY = pontos.fold(0.0, (a, p) => a + p.y);
  final somaXY = pontos.fold(0.0, (a, p) => a + p.x * p.y);
  final somaXX = pontos.fold(0.0, (a, p) => a + p.x * p.x);

  final denominador = n * somaXX - somaX * somaX;
  if (denominador == 0) return null;

  final slope = (n * somaXY - somaX * somaY) / denominador;
  final intercept = (somaY - slope * somaX) / n;

  final mediaY = somaY / n;
  final ssTot = pontos.fold(0.0, (a, p) => a + pow(p.y - mediaY, 2));
  final ssRes = pontos.fold(0.0, (a, p) => a + pow(p.y - (slope * p.x + intercept), 2));
  final r2 = ssTot == 0 ? 1.0 : 1 - (ssRes / ssTot);

  return (slope: slope, intercept: intercept, r2: r2);
}

/// Um ponto de medição do método indireto — `ponto_ensaio_ultrassom_indireto_medicao`.
/// Diferente do método direto, não tem posição/marcação na foto: é só um
/// nome + N leituras (D, velocidade). A "velocidade verdadeira" e o R² vêm
/// da regressão linear tempo x distância entre as leituras (o jeito padrão
/// de corrigir o erro sistemático de disparo do método indireto, em vez de
/// só tirar a média das velocidades cruas).
class MedicaoUltrassomIndiretoModel {
  final String? id;
  final String? idUltrassom;
  String nomePonto;
  List<LeituraUltrassomIndiretoModel> leituras;

  MedicaoUltrassomIndiretoModel({
    this.id,
    this.idUltrassom,
    required this.nomePonto,
    this.leituras = const [],
  });

  ({double slope, double intercept, double r2})? get _regressao =>
      _regressaoLinear(leituras.map((l) => (x: l.distancia, y: l.tempoMicrossegundos)).toList());

  // velocidade(m/s) = 10000 / slope(µs/cm) — inverso da mesma constante de
  // conversão usada em `tempoMicrossegundos`.
  double get valorVelocidade {
    final r = _regressao;
    if (r == null || r.slope == 0) return 0.0;
    return 10000 / r.slope;
  }

  double get correlacao => _regressao?.r2 ?? 0.0; // R², 0.0 a 1.0

  int get nPontos => leituras.length;

  factory MedicaoUltrassomIndiretoModel.fromJson(
    Map<String, dynamic> json, {
    List<LeituraUltrassomIndiretoModel> leituras = const [],
  }) {
    return MedicaoUltrassomIndiretoModel(
      id: json['id']?.toString(),
      idUltrassom: json['ponto_id']?.toString(),
      nomePonto: json['nome_ponto']?.toString() ?? 'Ponto',
      leituras: leituras,
    );
  }

  // `distancia` da tabela não é enviada — não fica claro o que ela
  // representaria no nível do ponto de medição já que cada leitura tem a
  // sua própria distância; avise se quiser que eu grave algo específico ali.
  Map<String, dynamic> toJson(String idUltrassom) {
    return {
      if (id != null) 'id': id,
      'ponto_id': idUltrassom,
      'nome_ponto': nomePonto,
      'n_pontos': nPontos,
      'valor_velocidade': valorVelocidade.round(),
      'correlacao': (correlacao * 100).round(),
    };
  }
}

/// A "Área de Ensaio" da Ultrassonografia — modo Indireto — 1 por ponto
/// geral (`ponto_ensaio_ultrassom`, `modo = 'indireto'`). Mesma tabela e
/// mesmas colunas de fotos/tipo de onda do modo Direto.
class PontoUltrassomIndiretoModel {
  final String? id;
  final String? pontoGeralId;
  final String pulsoUltrassonico; // 'Longitudinal' | 'Transversal' — coluna real: tipo_onda
  final String? foto1; // marcação da área
  final String? foto2; // realização do ensaio
  final List<MedicaoUltrassomIndiretoModel> medicoes;

  const PontoUltrassomIndiretoModel({
    this.id,
    this.pontoGeralId,
    this.pulsoUltrassonico = 'Longitudinal',
    this.foto1,
    this.foto2,
    this.medicoes = const [],
  });

  // Média das velocidades verdadeiras de cada ponto de medição (cada ponto
  // pesa igual) — usada como `valor_resultado` de `pontos_ensaios_geral`.
  double get mediaGeral {
    final valores = medicoes.map((m) => m.valorVelocidade).where((v) => v > 0).toList();
    if (valores.isEmpty) return 0.0;
    return valores.reduce((a, b) => a + b) / valores.length;
  }

  double get coefVariacaoGeral {
    final valores = medicoes.map((m) => m.valorVelocidade).where((v) => v > 0).toList();
    if (valores.length < 2) return 0.0;
    final m = mediaGeral;
    if (m == 0) return 0.0;
    final somaQuad = valores.fold<double>(0, (a, v) => a + (v - m) * (v - m));
    final desvio = sqrt(somaQuad / valores.length);
    return (desvio / m) * 100;
  }

  factory PontoUltrassomIndiretoModel.fromJson(
    Map<String, dynamic> json, {
    List<MedicaoUltrassomIndiretoModel> medicoes = const [],
  }) {
    return PontoUltrassomIndiretoModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_ensaio_id']?.toString(),
      pulsoUltrassonico: json['tipo_onda']?.toString() ?? 'Longitudinal',
      foto1: json['foto_1']?.toString(),
      foto2: json['foto_2']?.toString(),
      medicoes: medicoes,
    );
  }

  Map<String, dynamic> toJson({required String pontoEnsaioId}) {
    return {
      if (id != null) 'id': id,
      'ponto_ensaio_id': pontoEnsaioId,
      'modo': 'indireto',
      'tipo_onda': pulsoUltrassonico,
      if (foto1 != null) 'foto_1': foto1,
      if (foto2 != null) 'foto_2': foto2,
    };
  }

  PontoUltrassomIndiretoModel copyWith({
    String? id,
    String? pontoGeralId,
    String? pulsoUltrassonico,
    String? foto1,
    String? foto2,
    List<MedicaoUltrassomIndiretoModel>? medicoes,
  }) {
    return PontoUltrassomIndiretoModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      pulsoUltrassonico: pulsoUltrassonico ?? this.pulsoUltrassonico,
      foto1: foto1 ?? this.foto1,
      foto2: foto2 ?? this.foto2,
      medicoes: medicoes ?? this.medicoes,
    );
  }
}
