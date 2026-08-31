/// Uma medição individual (deslocamento x carga) de um ponto de medição.
class LeituraProvaCargaModel {
  final String? id;
  final String pontoMedicaoNome;
  int deslocamento;
  int carregamento;
  String etapa; // 'Carregamento' ou 'Descarregamento'
  String horario; // 'HH:mm'

  LeituraProvaCargaModel({
    this.id,
    required this.pontoMedicaoNome,
    required this.deslocamento,
    required this.carregamento,
    required this.etapa,
    required this.horario,
  });

  factory LeituraProvaCargaModel.fromJson(
    Map<String, dynamic> json, {
    required String pontoMedicaoNome,
  }) {
    String horarioStr = json['horario']?.toString() ?? '';
    if (horarioStr.length >= 5) horarioStr = horarioStr.substring(0, 5);

    return LeituraProvaCargaModel(
      id: json['id']?.toString(),
      pontoMedicaoNome: pontoMedicaoNome,
      deslocamento: (json['deslocamento'] as num?)?.toInt() ?? 0,
      carregamento: (json['carregamento'] as num?)?.toInt() ?? 0,
      etapa: json['etapa'] ?? 'Carregamento',
      horario: horarioStr ?? '00:00',
    );
  }

  Map<String, dynamic> toJson({required String pontoMedicaoId}) {
    return {
      if (id != null) 'id': id,
      'ponto_medicao_id': pontoMedicaoId,
      'deslocamento': deslocamento,
      'carregamento': carregamento,
      'etapa': etapa,
      'horario': horario,
    };
  }
}
