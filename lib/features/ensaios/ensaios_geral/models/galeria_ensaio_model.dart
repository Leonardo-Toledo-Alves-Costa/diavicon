class GaleriaEnsaioModel {
  final String id;
  final String imagemUrl;
  final String? legenda;
  final DateTime criadoEm;
  final String? criadoPor;
  final String pontoEnsaioId;

  GaleriaEnsaioModel({
    required this.id,
    required this.imagemUrl,
    this.legenda,
    required this.criadoEm,
    this.criadoPor,
    required this.pontoEnsaioId,
  });

  factory GaleriaEnsaioModel.fromJson(Map<String, dynamic> json) {
    return GaleriaEnsaioModel(
      id: json['id'] as String,
      imagemUrl: json['imagem_url'] as String,
      legenda: json['legenda'] as String?,
      criadoEm: DateTime.parse(json['criado_em'] as String),
      criadoPor: json['criado_por'] as String?,
      pontoEnsaioId: json['ponto_ensaio_id'] as String,
    );
  }
}