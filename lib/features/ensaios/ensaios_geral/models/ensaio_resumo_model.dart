import 'area_ensaio.dart';

class ResumoEnsaioModel {
  final String id;
  final String nome;
  final String iconePath;
  final int contratadas;
  final int realizadas;
  final AreaEnsaio area;

  ResumoEnsaioModel({
    required this.id,
    required this.nome,
    required this.iconePath,
    required this.contratadas,
    required this.realizadas,
    this.area = AreaEnsaio.concreto,
  });

  factory ResumoEnsaioModel.fromJson(Map<String, dynamic> json, int contratadas, int realizadas) {
    return ResumoEnsaioModel(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      // O caminho pode vir com espaço ou quebra de linha no cadastro do tipo.
      iconePath: json['icone_path']?.toString().trim() ?? 'assets/images/ensaios/default.png',
      contratadas: contratadas,
      realizadas: realizadas,
      area: AreaEnsaio.deBanco(json['area']),
    );
  }
}
