class LocalModel {
  final String id;
  final String estruturaId;
  final String nome;
  final String? tipologia;
  final String? condicaoExposicao;
  final String? descricao;

  LocalModel({
    required this.id,
    required this.estruturaId,
    required this.nome,
    this.tipologia,
    this.condicaoExposicao,
    this.descricao,
  });

  factory LocalModel.fromMap(Map<String, dynamic> map) {
    return LocalModel(
      id: map['id'] ?? '',
      estruturaId: map['estrutura_id'] ?? '',
      nome: map['nome'] ?? '',
      tipologia: map['tipologia'],
      condicaoExposicao: map['condicao_exposicao'],
      descricao: map['descricao'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'estrutura_id': estruturaId,
      'nome': nome,
      if (tipologia != null) 'tipologia': tipologia,
      if (condicaoExposicao != null) 'condicao_exposicao': condicaoExposicao,
      if (descricao != null) 'descricao': descricao,
    };
  }
}