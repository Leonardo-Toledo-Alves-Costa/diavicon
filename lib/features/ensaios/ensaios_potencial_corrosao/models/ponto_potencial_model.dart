import 'dart:math';

class PontoPotencialModel {
  final String? id;
  final String? pontoEnsaioId;
  final String? eletrodo;
  final String? tempoSaturacao;
  final String? temperatura;
  final String? espacamentoX;
  final String? espacamentoY;
  
  // Imagens
  final String? imagemElemento;
  final String? imagemEnsaio;
  final String? imagemElementoEnsaio;
  final String? imagemMapaCalor;
  final String? imagemElementoMapa;
  final String? opacidade;

  // Perspectiva (Homografia)
  final double? p1X, p1Y, p2X, p2Y, p3X, p3Y, p4X, p4Y;

  final List<PontoPotencialLeituraModel> leituras;

  PontoPotencialModel({
    this.id,
    this.pontoEnsaioId,
    this.eletrodo = 'Sulfato de Cobre',
    this.tempoSaturacao,
    this.temperatura,
    this.espacamentoX,
    this.espacamentoY,
    this.imagemElemento,
    this.imagemEnsaio,
    this.imagemElementoEnsaio,
    this.imagemMapaCalor,
    this.imagemElementoMapa,
    this.opacidade,
    this.p1X, this.p1Y, this.p2X, this.p2Y, this.p3X, this.p3Y, this.p4X, this.p4Y,
    this.leituras = const [],
  });

  // Calcula a média das leituras para exibir na listagem geral do App
  double get mediaPotencial {
    final validas = leituras.where((l) => l.potencialMv != null).toList();
    if (validas.isEmpty) return 0.0;
    final soma = validas.fold(0.0, (acc, item) => acc + item.potencialMv!);
    return soma / validas.length;
  }

  double get maxPotencial {
    final validas = leituras.where((l) => l.potencialMv != null).toList();
    if (validas.isEmpty) return 0.0;
    return validas.map((e) => e.potencialMv!).reduce(max);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (pontoEnsaioId != null) 'ponto_ensaio_id': pontoEnsaioId,
      'eletrodo': eletrodo,
      'tempo_saturacao': tempoSaturacao,
      'temperatura': temperatura,
      'espaçamento_x': espacamentoX,
      'espaçamento_y': espacamentoY,
      'imagem_elemento': imagemElemento,
      'imagem_ensaio': imagemEnsaio,
      'imagem_elemento_ensaio': imagemElementoEnsaio,
      'imagem_mapa_calor': imagemMapaCalor,
      'imagem_elemento_mapa': imagemElementoMapa,
      'opacidade': opacidade,
      'p1_x': p1X, 'p1_y': p1Y,
      'p2_x': p2X, 'p2_y': p2Y,
      'p3_x': p3X, 'p3_y': p3Y,
      'p4_x': p4X, 'p4_y': p4Y,
    };
  }

  factory PontoPotencialModel.fromMap(
    Map<String, dynamic> map, {
    List<PontoPotencialLeituraModel> leituras = const [],
  }) {
    return PontoPotencialModel(
      id: map['id'] as String?,
      pontoEnsaioId: map['ponto_ensaio_id'] as String?,
      eletrodo: map['eletrodo'] as String?,
      tempoSaturacao: map['tempo_saturacao'] as String?,
      temperatura: map['temperatura'] as String?,
      espacamentoX: map['espaçamento_x'] as String?,
      espacamentoY: map['espaçamento_y'] as String?,
      imagemElemento: map['imagem_elemento'] as String?,
      imagemEnsaio: map['imagem_ensaio'] as String?,
      imagemElementoEnsaio: map['imagem_elemento_ensaio'] as String?,
      imagemMapaCalor: map['imagem_mapa_calor'] as String?,
      imagemElementoMapa: map['imagem_elemento_mapa'] as String?,
      opacidade: map['opacidade'] as String?,
      p1X: (map['p1_x'] as num?)?.toDouble(),
      p1Y: (map['p1_y'] as num?)?.toDouble(),
      p2X: (map['p2_x'] as num?)?.toDouble(),
      p2Y: (map['p2_y'] as num?)?.toDouble(),
      p3X: (map['p3_x'] as num?)?.toDouble(),
      p3Y: (map['p3_y'] as num?)?.toDouble(),
      p4X: (map['p4_x'] as num?)?.toDouble(),
      p4Y: (map['p4_y'] as num?)?.toDouble(),
      leituras: leituras,
    );
  }
}

class PontoPotencialLeituraModel {
  final String? id;
  final String? pontoPotencialId;
  final int linha;
  final int coluna;
  final double? potencialMv;
  final String? idLeituraResistividade; // Vínculo com ensaio de resistividade

  PontoPotencialLeituraModel({
    this.id,
    this.pontoPotencialId,
    required this.linha,
    required this.coluna,
    this.potencialMv,
    this.idLeituraResistividade,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (pontoPotencialId != null) 'ponto_potencial_id': pontoPotencialId,
      'linha': linha,
      'coluna': coluna,
      'potencial_mv': potencialMv,
      'id_leitura_resistividade': idLeituraResistividade,
    };
  }

  factory PontoPotencialLeituraModel.fromMap(Map<String, dynamic> map) {
    return PontoPotencialLeituraModel(
      id: map['id'] as String?,
      pontoPotencialId: map['ponto_potencial_id'] as String?,
      linha: (map['linha'] as num?)?.toInt() ?? 0,
      coluna: (map['coluna'] as num?)?.toInt() ?? 0,
      potencialMv: (map['potencial_mv'] as num?)?.toDouble(),
      idLeituraResistividade: map['id_leitura_resistividade'] as String?,
    );
  }
}