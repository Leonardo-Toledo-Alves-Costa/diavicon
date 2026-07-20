class LocalModel {
  final String id;
  final String estruturaId;
  final String nome;

  LocalModel({
    required this.id,
    required this.estruturaId,
    required this.nome,
  });

  factory LocalModel.fromMap(Map<String, dynamic> map) {
    return LocalModel(
      id: map['id'] ?? '',
      estruturaId: map['estrutura_id'] ?? '',
      nome: map['nome'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'estrutura_id': estruturaId,
      'nome': nome,
    };
  }
}