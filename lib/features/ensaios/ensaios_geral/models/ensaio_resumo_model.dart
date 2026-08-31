class ResumoEnsaioModel {
  final String id;
  final String nome;
  final String iconePath;
  final int contratadas;
  final int realizadas;

  ResumoEnsaioModel({
    required this.id,
    required this.nome,
    required this.iconePath,
    required this.contratadas,
    required this.realizadas,
  });

  factory ResumoEnsaioModel.fromJson(Map<String, dynamic> json, int contratadas, int realizadas) {
    return ResumoEnsaioModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      iconePath: json['icone_path']?.toString() ?? 'assets/images/ensaios/default.png',
      contratadas: contratadas,
      realizadas: realizadas,
    );
  }
}