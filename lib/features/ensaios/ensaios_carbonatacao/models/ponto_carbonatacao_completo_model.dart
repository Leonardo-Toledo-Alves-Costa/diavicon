class MedicaoFrente {
  final String? id;
  final double profundidade;

  MedicaoFrente({
    this.id,
    required this.profundidade,
  });

  factory MedicaoFrente.fromJson(Map<String, dynamic> json) {
    return MedicaoFrente(
      id: json['id'] as String?,
      profundidade: (json['profundidade'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson({required String userId, required String carbId}) {
    return {
      if (id != null) 'id': id,
      'criado_em': DateTime.now().toIso8601String(),
      'criado_por': userId,
      'profundidade': profundidade,
      'ponto_ensaio_id': carbId,
    };
  }
}

class PontoCarbonatacaoCompletoModel {
  final String? idGeral;
  final String nomePonto;
  final String elementoNome;
  final String tipoElemento;
  final String local;

  final double? cobArmP;
  final double? bitArmP;
  final double? cobArmS;
  final double? bitArmS;
  
  final String? urlFotoQuebra;
  final String? urlFotoAspersao;

  final List<MedicaoFrente> frentes;

  PontoCarbonatacaoCompletoModel({
    this.idGeral,
    required this.nomePonto,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    this.cobArmP,
    this.bitArmP,
    this.cobArmS,
    this.bitArmS,
    this.urlFotoQuebra,
    this.urlFotoAspersao,
    this.frentes = const [],
  });
}