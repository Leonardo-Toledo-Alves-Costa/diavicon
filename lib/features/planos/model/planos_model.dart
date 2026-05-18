class PlanosModel {
  final String id;
  final String nome;
  final String descricao;
  final double valor;
  final int vigenciaDias;
  final int armazenamentoMb;

  PlanosModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.valor,
    required this.vigenciaDias,
    required this.armazenamentoMb,
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
    };
  }

  PlanosModel copywith({
    String? id,
    String? nome,
    String? descricao,
    double? valor,
    int? vigenciaDias,
    int? armazenamentoMb,
  }) {
    return PlanosModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      vigenciaDias: vigenciaDias ?? this.vigenciaDias,
      armazenamentoMb: armazenamentoMb ?? this.armazenamentoMb,
    );
  }
}
