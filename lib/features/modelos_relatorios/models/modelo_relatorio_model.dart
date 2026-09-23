// Modelo (template) de relatório padronizado que a empresa cadastra para um
// tipo de ensaio. Espelha a tabela `modelos_relatorio` no Supabase.

class ModeloRelatorioModel {
  final String id;
  final String empresaId;
  final String tipoEnsaioId;
  final String nome;
  final String? descricao;
  final DateTime criadoEm;
  final Map<String, dynamic> schemaJson;
  final bool ehPadrao;
  final String? duplicadoDeId;

  const ModeloRelatorioModel({
    required this.id,
    required this.empresaId,
    required this.tipoEnsaioId,
    required this.nome,
    this.descricao,
    required this.criadoEm,
    this.schemaJson = const {},
    this.ehPadrao = false,
    this.duplicadoDeId,
  });

  factory ModeloRelatorioModel.fromJson(Map<String, dynamic> json) {
    return ModeloRelatorioModel(
      id: json['id'].toString(),
      empresaId: json['empresa_id'].toString(),
      tipoEnsaioId: json['tipo_ensaio_id'].toString(),
      nome: json['nome']?.toString() ?? 'Modelo sem nome',
      descricao: json['descricao']?.toString(),
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? '') ?? DateTime.now(),
      schemaJson: (json['schema_json'] as Map?)?.cast<String, dynamic>() ?? const {},
      ehPadrao: json['eh_padrao'] as bool? ?? false,
      duplicadoDeId: json['duplicado_de_id']?.toString(),
    );
  }
}

// Um tipo de ensaio (`tipos_ensaio`) com a contagem de modelos de relatório
// já cadastrados pela empresa para ele — usado na tela "Modelos de Relatórios".
class ResumoModelosEnsaioModel {
  final String tipoEnsaioId;
  final String nome;
  final String iconePath;
  final int quantidadeModelos;

  const ResumoModelosEnsaioModel({
    required this.tipoEnsaioId,
    required this.nome,
    required this.iconePath,
    required this.quantidadeModelos,
  });

  factory ResumoModelosEnsaioModel.fromJson(Map<String, dynamic> json, int quantidadeModelos) {
    return ResumoModelosEnsaioModel(
      tipoEnsaioId: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? '',
      iconePath: json['icone_path']?.toString().trim() ?? 'assets/images/ensaios/default.png',
      quantidadeModelos: quantidadeModelos,
    );
  }
}
