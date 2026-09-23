import 'dart:math';

/// Uma leitura da malha (linha, coluna, velocidade) —
/// `ponto_ensaio_ultrassom_mapeamento_leitura`. Ao contrário de
/// `ponto_ensaio_potencial_leitura` (linha/coluna `bigint`, potencial_mv
/// `double precision`), aqui as 3 colunas são `text` no banco — precisa
/// converter pra número na leitura e de volta pra string na escrita.
class LeituraUltrassomMapeamentoModel {
  final String? id;
  final String? idMapeamento;
  final int linha;
  final int coluna;
  final double? velocidade;

  LeituraUltrassomMapeamentoModel({this.id, this.idMapeamento, required this.linha, required this.coluna, this.velocidade});

  Map<String, dynamic> toJson(String idMapeamento) {
    return {
      if (id != null) 'id': id,
      'ponto_id': idMapeamento,
      'linha': linha.toString(),
      'coluna': coluna.toString(),
      'velocidade': velocidade?.round().toString(),
    };
  }

  factory LeituraUltrassomMapeamentoModel.fromJson(Map<String, dynamic> json) {
    return LeituraUltrassomMapeamentoModel(
      id: json['id']?.toString(),
      idMapeamento: json['ponto_id']?.toString(),
      linha: int.tryParse(json['linha']?.toString() ?? '') ?? 0,
      coluna: int.tryParse(json['coluna']?.toString() ?? '') ?? 0,
      velocidade: double.tryParse(json['velocidade']?.toString() ?? ''),
    );
  }
}

/// A "Área de Ensaio" da Ultrassonografia — modo Mapeamento — combina uma
/// linha de `ponto_ensaio_ultrassom` (modo='mapeamento', compartilhada com
/// Direto/Indireto: fotos + tipo_onda) com sua própria
/// `ponto_ensaio_ultrassom_mapeamento` (1:1, calibração de perspectiva +
/// malha) e as leituras da malha. Mesma ideia de coleta+análise de
/// `PontoPotencialModel`, mas com o parentesco Direto/Indireto/Mapeamento
/// dividido em 2 tabelas em vez de 1.
class PontoUltrassomMapeamentoModel {
  final String? id; // ponto_ensaio_ultrassom.id
  final String? mapeamentoId; // ponto_ensaio_ultrassom_mapeamento.id
  final String? pontoGeralId;
  final String pulsoUltrassonico; // 'Longitudinal' | 'Transversal' — tipo_onda
  final String? foto1; // marcação da área — base do mapa de calor
  final String? foto2; // realização do ensaio
  final String? espacamentoX;
  final String? espacamentoY;
  final String? opacidade;
  final double? p1X, p1Y, p2X, p2Y, p3X, p3Y, p4X, p4Y;
  final List<LeituraUltrassomMapeamentoModel> leituras;

  const PontoUltrassomMapeamentoModel({
    this.id,
    this.mapeamentoId,
    this.pontoGeralId,
    this.pulsoUltrassonico = 'Longitudinal',
    this.foto1,
    this.foto2,
    this.espacamentoX,
    this.espacamentoY,
    this.opacidade,
    this.p1X,
    this.p1Y,
    this.p2X,
    this.p2Y,
    this.p3X,
    this.p3Y,
    this.p4X,
    this.p4Y,
    this.leituras = const [],
  });

  double get mediaVelocidade {
    final validas = leituras.where((l) => l.velocidade != null).map((l) => l.velocidade!).toList();
    if (validas.isEmpty) return 0.0;
    return validas.reduce((a, b) => a + b) / validas.length;
  }

  double get maiorVelocidade {
    final validas = leituras.where((l) => l.velocidade != null).map((l) => l.velocidade!).toList();
    if (validas.isEmpty) return 0.0;
    return validas.reduce(max);
  }

  double get menorVelocidade {
    final validas = leituras.where((l) => l.velocidade != null).map((l) => l.velocidade!).toList();
    if (validas.isEmpty) return 0.0;
    return validas.reduce(min);
  }

  double get coefVariacao {
    final validas = leituras.where((l) => l.velocidade != null).map((l) => l.velocidade!).toList();
    if (validas.length < 2) return 0.0;
    final m = mediaVelocidade;
    if (m == 0) return 0.0;
    final somaQuad = validas.fold<double>(0, (a, v) => a + (v - m) * (v - m));
    final desvio = sqrt(somaQuad / validas.length);
    return (desvio / m) * 100;
  }

  PontoUltrassomMapeamentoModel copyWith({
    String? id,
    String? mapeamentoId,
    String? pontoGeralId,
    String? pulsoUltrassonico,
    String? foto1,
    String? foto2,
    String? espacamentoX,
    String? espacamentoY,
    String? opacidade,
    double? p1X,
    double? p1Y,
    double? p2X,
    double? p2Y,
    double? p3X,
    double? p3Y,
    double? p4X,
    double? p4Y,
    List<LeituraUltrassomMapeamentoModel>? leituras,
  }) {
    return PontoUltrassomMapeamentoModel(
      id: id ?? this.id,
      mapeamentoId: mapeamentoId ?? this.mapeamentoId,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      pulsoUltrassonico: pulsoUltrassonico ?? this.pulsoUltrassonico,
      foto1: foto1 ?? this.foto1,
      foto2: foto2 ?? this.foto2,
      espacamentoX: espacamentoX ?? this.espacamentoX,
      espacamentoY: espacamentoY ?? this.espacamentoY,
      opacidade: opacidade ?? this.opacidade,
      p1X: p1X ?? this.p1X,
      p1Y: p1Y ?? this.p1Y,
      p2X: p2X ?? this.p2X,
      p2Y: p2Y ?? this.p2Y,
      p3X: p3X ?? this.p3X,
      p3Y: p3Y ?? this.p3Y,
      p4X: p4X ?? this.p4X,
      p4Y: p4Y ?? this.p4Y,
      leituras: leituras ?? this.leituras,
    );
  }

  // Payload da tabela pai `ponto_ensaio_ultrassom` (compartilhada com
  // Direto/Indireto, diferenciada por `modo`).
  Map<String, dynamic> toJsonUltrassom({required String pontoEnsaioId}) {
    return {
      if (id != null) 'id': id,
      'ponto_ensaio_id': pontoEnsaioId,
      'modo': 'mapeamento',
      'tipo_onda': pulsoUltrassonico,
      if (foto1 != null) 'foto_1': foto1,
      if (foto2 != null) 'foto_2': foto2,
    };
  }

  // Payload da tabela filha `ponto_ensaio_ultrassom_mapeamento` (calibração
  // de perspectiva + malha), FK `ponto_id` -> ponto_ensaio_ultrassom.id.
  Map<String, dynamic> toJsonMapeamento(String idUltrassom) {
    return {
      if (mapeamentoId != null) 'id': mapeamentoId,
      'ponto_id': idUltrassom,
      'espacamento_x': espacamentoX,
      'espacamento_y': espacamentoY,
      'opacidade': opacidade,
      'p1_x': p1X, 'p1_y': p1Y,
      'p2_x': p2X, 'p2_y': p2Y,
      'p3_x': p3X, 'p3_y': p3Y,
      'p4_x': p4X, 'p4_y': p4Y,
    };
  }
}
