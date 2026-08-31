class InspecaoVisualGeralModel {
  final String id;
  final String nome;
  final String tipo;
  final String? descricao;
  final int totalRegistros;
  final List<String> locaisAtendidos;
  final String? iconePath; 
  final DateTime? criadoEm; 
  final String? criadoPor;

  InspecaoVisualGeralModel({
    required this.id,
    required this.nome,
    required this.tipo,
    this.descricao,
    required this.totalRegistros,
    required this.locaisAtendidos,
    this.iconePath,
    this.criadoEm,
    this.criadoPor,
  });

  factory InspecaoVisualGeralModel.fromMap(Map<String, dynamic> map) {
    final pontos = map['ponto_inspecao_visual'] as List<dynamic>? ?? [];
    final locais = pontos
        .map((p) => p['estruturas_locais']?['nome']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    return InspecaoVisualGeralModel(
      id: map['id'],
      nome: map['nome'] ?? 'Sem Nome',
      tipo: map['tipo'] ?? 'Visual',
      descricao: map['descricao'],
      totalRegistros: pontos.length,
      locaisAtendidos: locais,
      // Recebe o ícone e a data provenientes do inner join no Repository
      iconePath: map['pontos_ensaios_geral']?['tipos_ensaio']?['icone_path'],
      criadoEm: map['pontos_ensaios_geral']?['criado_em'] != null 
          ? DateTime.tryParse(map['pontos_ensaios_geral']['criado_em']) 
          : null,
      criadoPor: map['criado_por'],
    );
  }
}