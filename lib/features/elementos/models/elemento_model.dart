class ElementoModel {
  final String? id;
  final String? nome;
  final String? tipo;
  final String? topologia;
  final String? revestimento;
  final double? posicaoX;
  final double? posicaoY;
  final double? posicaoZ;
  final String? dimensoes;
  final String? secao;
  final String? microclima;
  final String? caa; // Classe de Agressividade Ambiental
  final String? estruturaId;
  final List<String>? fotos;
  final String? observacoes;
  final bool? ativo;
  final DateTime? criadoEm;

  ElementoModel({
    this.id,
    this.nome,
    this.tipo,
    this.topologia,
    this.revestimento,
    this.posicaoX,
    this.posicaoY,
    this.posicaoZ,
    this.dimensoes,
    this.secao,
    this.microclima,
    this.caa,
    this.estruturaId,
    this.fotos,
    this.observacoes,
    this.ativo,
    this.criadoEm,
  });

  factory ElementoModel.fromMap(Map<String, dynamic> map) {
    return ElementoModel(
      id: map['id'],
      nome: map['nome'],
      tipo: map['tipo'],
      topologia: map['topologia'],
      revestimento: map['revestimento'],
      posicaoX: (map['posicao_x'] as num?)?.toDouble(),
      posicaoY: (map['posicao_y'] as num?)?.toDouble(),
      posicaoZ: (map['posicao_z'] as num?)?.toDouble(),
      dimensoes: map['dimensoes'],
      secao: map['secao'],
      microclima: map['microclima'],
      caa: map['caa'],
      estruturaId: map['estrutura_id'],
      fotos: map['fotos'] != null
          ? List<String>.from(map['fotos'])
          : null,
      observacoes: map['observacoes'],
      ativo: map['ativo'],
      criadoEm: map['criado_em'] != null
          ? DateTime.parse(map['criado_em'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'tipo': tipo,
      'topologia': topologia,
      'revestimento': revestimento,
      'posicao_x': posicaoX,
      'posicao_y': posicaoY,
      'posicao_z': posicaoZ,
      'dimensoes': dimensoes,
      'secao': secao,
      'microclima': microclima,
      'caa': caa,
      'estrutura_id': estruturaId,
      'fotos': fotos,
      'observacoes': observacoes,
      'ativo': ativo ?? true,
    };
  }

  ElementoModel copyWith({
    String? id,
    String? nome,
    String? tipo,
    String? topologia,
    String? revestimento,
    double? posicaoX,
    double? posicaoY,
    double? posicaoZ,
    String? dimensoes,
    String? secao,
    String? microclima,
    String? caa,
    String? estruturaId,
    List<String>? fotos,
    String? observacoes,
    bool? ativo,
  }) {
    return ElementoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      tipo: tipo ?? this.tipo,
      topologia: topologia ?? this.topologia,
      revestimento: revestimento ?? this.revestimento,
      posicaoX: posicaoX ?? this.posicaoX,
      posicaoY: posicaoY ?? this.posicaoY,
      posicaoZ: posicaoZ ?? this.posicaoZ,
      dimensoes: dimensoes ?? this.dimensoes,
      secao: secao ?? this.secao,
      microclima: microclima ?? this.microclima,
      caa: caa ?? this.caa,
      estruturaId: estruturaId ?? this.estruturaId,
      fotos: fotos ?? this.fotos,
      observacoes: observacoes ?? this.observacoes,
      ativo: ativo ?? this.ativo,
    );
  }
}