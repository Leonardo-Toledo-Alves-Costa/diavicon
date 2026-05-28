class PlanosModel {
  final String id;
  final String nome;
  final String descricao;
  final double valor;
  final int vigenciaDias;
  final int armazenamentoMb;
  final List<String>? features;

  PlanosModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.vigenciaDias,
    required this.armazenamentoMb,
    this.features,
  });

  // Converte o JSON do Supabase para o Objeto Dart
  factory PlanosModel.fromMap(Map<String, dynamic> map) {
    return PlanosModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      valor: map['valor'] != null ? (map['valor'] as num).toDouble() : 0.0,
      vigenciaDias: map['vigencia_dias'] ?? 0,
      armazenamentoMb: map['armazenamento_mb'] ?? 0,
      features: map['features'] != null
          ? List<String>.from(map['features'])
          : null,
    );
  }

  // Converte o Objeto Dart para JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'valor': valor,
      'vigencia_dias': vigenciaDias,
      'armazenamento_mb': armazenamentoMb,
      'features': features,
    };
  }

  PlanosModel copywith({
    String? id,
    String? nome,
    String? descricao,
    double? valor,
    int? vigenciaDias,
    int? armazenamentoMb,
    List<String>? features,
  }) {
    return PlanosModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      vigenciaDias: vigenciaDias ?? this.vigenciaDias,
      armazenamentoMb: armazenamentoMb ?? this.armazenamentoMb,
      features: features ?? this.features,
    );
  }
}
