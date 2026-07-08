class RegiaoEnsaioModel {
  final String id;
  final String plantaId;
  final String empresaId;
  final String? elementoId;
  final int numero;
  final double posicaoX;
  final double posicaoY;
  
  // 🔥 NOVOS CAMPOS DE FORMA E DIMENSÃO
  final String tipoMarcacao;
  final double marcacaoLargura;
  final double marcacaoAltura;
  final double marcacaoRotacao;
  
  final double tamanhoMarcacao; // Mantido por retrocompatibilidade
  final String corMarcacao;
  final String? descricao;
  
  final String? elementoNome;
  final String? elementoTipo;
  final int qtdEnsaios;

  RegiaoEnsaioModel({
    required this.id, required this.plantaId, required this.empresaId, this.elementoId,
    required this.numero, required this.posicaoX, required this.posicaoY,
    this.tipoMarcacao = 'Círculo', this.marcacaoLargura = 0.05, this.marcacaoAltura = 0.05, this.marcacaoRotacao = 0.0,
    required this.tamanhoMarcacao, this.corMarcacao = '#238E5A', this.descricao,
    this.elementoNome, this.elementoTipo, this.qtdEnsaios = 0, 
  });

  factory RegiaoEnsaioModel.fromMap(Map<String, dynamic> map) {
    final elementoData = map['elementos_estruturais'] as Map<String, dynamic>?;
    return RegiaoEnsaioModel(
      id: map['id'] ?? '', plantaId: map['planta_id'] ?? '', empresaId: map['empresa_id'] ?? '', elementoId: map['elemento_id'],
      numero: map['numero'] ?? 1,
      posicaoX: (map['posicao_x'] as num?)?.toDouble() ?? 0.0,
      posicaoY: (map['posicao_y'] as num?)?.toDouble() ?? 0.0,
      
      // 🔥 LÊ OS NOVOS VALORES
      tipoMarcacao: map['tipo_marcacao'] ?? 'Círculo',
      marcacaoLargura: (map['marcacao_largura'] as num?)?.toDouble() ?? 0.05,
      marcacaoAltura: (map['marcacao_altura'] as num?)?.toDouble() ?? 0.05,
      marcacaoRotacao: (map['marcacao_rotacao'] as num?)?.toDouble() ?? 0.0,
      
      tamanhoMarcacao: (map['tamanho_marcacao'] as num?)?.toDouble() ?? 30.0,
      corMarcacao: map['cor_marcacao'] ?? '#238E5A', descricao: map['descricao'],
      elementoNome: elementoData?['nome'], elementoTipo: elementoData?['tipo'],
    );
  }
}
// O resto do ficheiro (RegioesFiltro e regioesEnsaioProvider) continua igual!