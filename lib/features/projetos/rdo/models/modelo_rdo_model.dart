// Modelo (template) de relatório de RDO que a empresa cadastra — espelha
// `modelo_relatorio_rdo` (schema real: id, empresa_id, nome, descricao,
// criado_por, criado_em, schema_json — sem `eh_padrao`/`duplicado_de_id`,
// diferente de `modelos_relatorios` dos ensaios).
class ModeloRdoModel {
  final String id;
  final String empresaId;
  final String nome;
  final String? descricao;
  final DateTime criadoEm;
  final Map<String, dynamic> schemaJson;

  const ModeloRdoModel({
    required this.id,
    required this.empresaId,
    required this.nome,
    this.descricao,
    required this.criadoEm,
    this.schemaJson = const {},
  });

  factory ModeloRdoModel.fromJson(Map<String, dynamic> json) {
    return ModeloRdoModel(
      id: json['id'].toString(),
      empresaId: json['empresa_id'].toString(),
      nome: json['nome']?.toString() ?? 'Modelo sem nome',
      descricao: json['descricao']?.toString(),
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? '') ?? DateTime.now(),
      schemaJson: (json['schema_json'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
