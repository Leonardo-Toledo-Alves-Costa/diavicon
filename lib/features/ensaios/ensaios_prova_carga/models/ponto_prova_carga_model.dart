/// Representa a "Área de Ensaio" da prova de carga estática (1 por ponto geral).
///
/// As colunas de marcação (`marca_x/y/largura/altura`) são `bigint` no banco,
/// então guardamos a fração 0.0-1.0 multiplicada por 1000 (per-mille) e
/// convertemos de volta ao ler. `marca_rotacao` já é um grau inteiro (0-360).
class PontoProvaCargaModel {
  final String? id;
  final String? pontoGeralId;
  final String nome;
  final String? elementoId;
  final int cargaTotal;
  final int carregamento;
  final int etapaCarregamento;
  final int etapaDescarregamento;
  final String? plantaFoto;
  final double marcaX;
  final double marcaY;
  final double marcaLargura;
  final double marcaAltura;
  final double marcaRotacao;
  final String marcaForma;

  PontoProvaCargaModel({
    this.id,
    this.pontoGeralId,
    required this.nome,
    this.elementoId,
    this.cargaTotal = 0,
    this.carregamento = 0,
    this.etapaCarregamento = 0,
    this.etapaDescarregamento = 0,
    this.plantaFoto,
    this.marcaX = 0.5,
    this.marcaY = 0.5,
    this.marcaLargura = 0.3,
    this.marcaAltura = 0.3,
    this.marcaRotacao = 0.0,
    this.marcaForma = 'Retângulo',
  });

  static double _fromPerMille(dynamic v, double fallback) {
    if (v == null) return fallback;
    return (v as num).toDouble() / 1000.0;
  }

  static int _toPerMille(double v) => (v.clamp(0.0, 1.0) * 1000).round();

  factory PontoProvaCargaModel.fromJson(Map<String, dynamic> json) {
    return PontoProvaCargaModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_geral_id']?.toString(),
      nome: json['nome'] ?? '',
      elementoId: json['elemento_id']?.toString(),
      cargaTotal: (json['carga_total'] as num?)?.toInt() ?? 0,
      carregamento: (json['carregamento'] as num?)?.toInt() ?? 0,
      etapaCarregamento: (json['etapa_carregamento'] as num?)?.toInt() ?? 0,
      etapaDescarregamento: (json['etapa_descarregamento'] as num?)?.toInt() ?? 0,
      plantaFoto: json['planta_foto'],
      marcaX: _fromPerMille(json['marca_x'], 0.5),
      marcaY: _fromPerMille(json['marca_y'], 0.5),
      marcaLargura: _fromPerMille(json['marca_largura'], 0.3),
      marcaAltura: _fromPerMille(json['marca_altura'], 0.3),
      marcaRotacao: (json['marca_rotacao'] as num?)?.toDouble() ?? 0.0,
      marcaForma: json['marca_forma'] ?? 'Retângulo',
    );
  }

  Map<String, dynamic> toJson({required String pontoGeralId}) {
    return {
      if (id != null) 'id': id,
      'ponto_geral_id': pontoGeralId,
      'nome': nome,
      'elemento_id': elementoId,
      'carga_total': cargaTotal,
      'carregamento': carregamento,
      'etapa_carregamento': etapaCarregamento,
      'etapa_descarregamento': etapaDescarregamento,
      if (plantaFoto != null) 'planta_foto': plantaFoto,
      'marca_x': _toPerMille(marcaX),
      'marca_y': _toPerMille(marcaY),
      'marca_largura': _toPerMille(marcaLargura),
      'marca_altura': _toPerMille(marcaAltura),
      'marca_rotacao': marcaRotacao.round(),
      'marca_forma': marcaForma,
    };
  }

  PontoProvaCargaModel copyWith({
    String? id,
    String? pontoGeralId,
    String? nome,
    String? elementoId,
    int? cargaTotal,
    int? carregamento,
    int? etapaCarregamento,
    int? etapaDescarregamento,
    String? plantaFoto,
    double? marcaX,
    double? marcaY,
    double? marcaLargura,
    double? marcaAltura,
    double? marcaRotacao,
    String? marcaForma,
  }) {
    return PontoProvaCargaModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      nome: nome ?? this.nome,
      elementoId: elementoId ?? this.elementoId,
      cargaTotal: cargaTotal ?? this.cargaTotal,
      carregamento: carregamento ?? this.carregamento,
      etapaCarregamento: etapaCarregamento ?? this.etapaCarregamento,
      etapaDescarregamento: etapaDescarregamento ?? this.etapaDescarregamento,
      plantaFoto: plantaFoto ?? this.plantaFoto,
      marcaX: marcaX ?? this.marcaX,
      marcaY: marcaY ?? this.marcaY,
      marcaLargura: marcaLargura ?? this.marcaLargura,
      marcaAltura: marcaAltura ?? this.marcaAltura,
      marcaRotacao: marcaRotacao ?? this.marcaRotacao,
      marcaForma: marcaForma ?? this.marcaForma,
    );
  }
}
