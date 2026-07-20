class PlantaModel {
  final String id;
  final String estruturaId;
  final String titulo;
  final String localVinculado;
  final String arquivoUrl;
  final String? tamanhoArquivo;
  final DateTime? criadoEm;

  PlantaModel({
    required this.id,
    required this.estruturaId,
    required this.titulo,
    required this.localVinculado,
    required this.arquivoUrl,
    this.tamanhoArquivo,
    this.criadoEm,
  });

  factory PlantaModel.fromMap(Map<String, dynamic> map) {
    return PlantaModel(
      id: map['id'] ?? '',
      estruturaId: map['estrutura_id'] ?? '',
      titulo: map['titulo'] ?? '',
      localVinculado: map['local_vinculado'] ?? '',
      arquivoUrl: map['arquivo_url'] ?? '',
      tamanhoArquivo: map['tamanho_arquivo'],
      criadoEm: map['criado_em'] != null ? DateTime.parse(map['criado_em']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'estrutura_id': estruturaId,
      'titulo': titulo,
      'local_vinculado': localVinculado,
      'arquivo_url': arquivoUrl,
      if (tamanhoArquivo != null) 'tamanho_arquivo': tamanhoArquivo,
    };
  }
}