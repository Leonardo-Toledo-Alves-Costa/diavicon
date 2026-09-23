import 'dashboard_card_model.dart';

enum NivelAplicacaoBi {
  estruturaMultiProjeto('estrutura_multi_projeto', 'Estrutura monitorada (n projetos)'),
  projeto('projeto', 'Projeto'),
  estruturaNoProjeto('estrutura_no_projeto', 'Estrutura'),
  elementoNoProjeto('elemento_no_projeto', 'Elemento');

  final String valor;
  final String rotulo;
  const NivelAplicacaoBi(this.valor, this.rotulo);

  static NivelAplicacaoBi fromValor(String? v) => NivelAplicacaoBi.values.firstWhere((n) => n.valor == v, orElse: () => NivelAplicacaoBi.projeto);
}

class DashboardModeloModel {
  final String id;
  final DateTime criadoEm;
  final String empresaId;
  final String? criadoPor;
  final NivelAplicacaoBi nivelAplicacao;
  final String nome;
  final bool isPadrao;
  final String? modeloOrigemId;
  final List<DashboardCardModel> cards;

  const DashboardModeloModel({
    required this.id,
    required this.criadoEm,
    required this.empresaId,
    this.criadoPor,
    required this.nivelAplicacao,
    required this.nome,
    this.isPadrao = false,
    this.modeloOrigemId,
    this.cards = const [],
  });

  factory DashboardModeloModel.fromMap(Map<String, dynamic> m) => DashboardModeloModel(
        id: m['id'].toString(),
        criadoEm: DateTime.tryParse(m['criado_em']?.toString() ?? '') ?? DateTime.now(),
        empresaId: m['empresa_id'].toString(),
        criadoPor: m['criado_por']?.toString(),
        nivelAplicacao: NivelAplicacaoBi.fromValor(m['nivel_aplicacao']?.toString()),
        nome: m['nome']?.toString() ?? 'Sem nome',
        isPadrao: m['is_padrao']?.toString() == 'true',
        modeloOrigemId: m['modelo_origem_id']?.toString(),
        cards: cardsFromSchemaJson(m['schema_json']),
      );

  Map<String, dynamic> toInsertMap({required String empresaId, required String? criadoPor}) => {
        'empresa_id': empresaId,
        'criado_por': criadoPor,
        'nivel_aplicacao': nivelAplicacao.valor,
        'nome': nome,
        'is_padrao': isPadrao.toString(),
        if (modeloOrigemId != null) 'modelo_origem_id': modeloOrigemId,
        'schema_json': cardsParaSchemaJson(cards),
      };

  Map<String, dynamic> toUpdateMap() => {
        'nome': nome,
        'is_padrao': isPadrao.toString(),
        'schema_json': cardsParaSchemaJson(cards),
      };
}

class DashboardInstanciaModel {
  final String id;
  final DateTime criadoEm;
  final String modeloId;
  final String? projetoId;
  final String? estruturaId;
  final String? elementoId;
  final Map<String, dynamic>? filtrosGerais;
  final Map<String, dynamic>? overridesJson;
  final String empresaId;
  final NivelAplicacaoBi nivelAplicacao;

  const DashboardInstanciaModel({
    required this.id,
    required this.criadoEm,
    required this.modeloId,
    this.projetoId,
    this.estruturaId,
    this.elementoId,
    this.filtrosGerais,
    this.overridesJson,
    required this.empresaId,
    required this.nivelAplicacao,
  });

  factory DashboardInstanciaModel.fromMap(Map<String, dynamic> m) => DashboardInstanciaModel(
        id: m['id'].toString(),
        criadoEm: DateTime.tryParse(m['criado_em']?.toString() ?? '') ?? DateTime.now(),
        modeloId: m['modelo_id'].toString(),
        projetoId: m['projeto_id']?.toString(),
        estruturaId: m['estrutura_id']?.toString(),
        elementoId: m['elemento_id']?.toString(),
        filtrosGerais: (m['filtros_gerais_id'] as Map?)?.cast<String, dynamic>(),
        overridesJson: (m['overrides_json'] as Map?)?.cast<String, dynamic>(),
        empresaId: m['empresa_id'].toString(),
        nivelAplicacao: NivelAplicacaoBi.fromValor(m['nivel_aplicacao']?.toString()),
      );

  Map<String, dynamic> toInsertMap() => {
        'modelo_id': modeloId,
        if (projetoId != null) 'projeto_id': projetoId,
        if (estruturaId != null) 'estrutura_id': estruturaId,
        if (elementoId != null) 'elemento_id': elementoId,
        if (filtrosGerais != null) 'filtros_gerais_id': filtrosGerais,
        if (overridesJson != null) 'overrides_json': overridesJson,
        'empresa_id': empresaId,
        'nivel_aplicacao': nivelAplicacao.valor,
      };
}
