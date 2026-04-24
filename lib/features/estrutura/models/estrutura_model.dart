class EstruturaModel {
  final String id;
  final String? nome;
  final String? tipo;
  final String? descricao;
  final DateTime? criadoEm;
  final String? imageUrl;


  EstruturaModel({
    required this.id,
    this.nome,
    this.tipo,
    this.descricao,
    this.criadoEm,
    this.imageUrl,
  });

  factory EstruturaModel.fromMap(Map<String, dynamic> map) {
    return EstruturaModel(
      id: map['id'],
      nome: map['nome'],
      tipo: map['tipo'],
      descricao: map['descricao'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo,
      'descricao': descricao,
    };
  }
}