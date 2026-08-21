class SistemaHabitacionalModel {
  final String id;
  final String nome;

  SistemaHabitacionalModel({
    required this.id,
    required this.nome,
  });

  factory SistemaHabitacionalModel.fromMap(Map<String, dynamic> map) {
    return SistemaHabitacionalModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
    );
  }
}