class GaleriaRdoModel {
  final String id;
  final String foto;
  final String? descricao;
  final DateTime criadoEm;
  final String rdoId;

  GaleriaRdoModel({
    required this.id,
    required this.foto,
    this.descricao,
    required this.criadoEm,
    required this.rdoId,
  });

  factory GaleriaRdoModel.fromJson(Map<String, dynamic> json) {
    return GaleriaRdoModel(
      id: json['id'] as String,
      foto: json['foto'] as String,
      descricao: json['descricao'] as String?,
      criadoEm: DateTime.parse(json['criado_em'] as String),
      rdoId: json['rdo_id'] as String,
    );
  }
}
