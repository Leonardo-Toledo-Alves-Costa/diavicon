/// Um ponto de medição (transdutor de deslocamento) dentro da Área de Ensaio.
///
/// Enquanto o ponto ainda não foi salvo no Supabase, [id] é nulo e as
/// leituras em memória se referenciam a ele pelo [nome] (único dentro do
/// ensaio, ex. "Ponto de Medição 1") — mesmo esquema de agrupamento por nome
/// já usado em `PontoResistividadeLeituraModel`.
class PontoMedicaoModel {
  final String? id;
  final String? pontoCargaId;
  String nome;
  double x;
  double y;
  double tamanho;
  int? deslocMax;
  String? descricao;
  String? tipoElemento;

  PontoMedicaoModel({
    this.id,
    this.pontoCargaId,
    required this.nome,
    required this.x,
    required this.y,
    this.tamanho = 0.05,
    this.deslocMax,
    this.descricao,
    this.tipoElemento,
  });

  static double _fromPerMille(dynamic v, double fallback) {
    if (v == null) return fallback;
    return (v as num).toDouble() / 1000.0;
  }

  static int _toPerMille(double v) => (v.clamp(0.0, 1.0) * 1000).round();

  factory PontoMedicaoModel.fromJson(Map<String, dynamic> json) {
    return PontoMedicaoModel(
      id: json['id']?.toString(),
      pontoCargaId: json['ponto_carga_id']?.toString(),
      nome: json['nome'] ?? '',
      x: _fromPerMille(json['x'], 0.5),
      y: _fromPerMille(json['y'], 0.5),
      tamanho: _fromPerMille(json['tamanho'], 0.05),
      deslocMax: (json['desloc_max'] as num?)?.toInt(),
      descricao: json['descricao'],
      tipoElemento: json['tipo_elemento'],
    );
  }

  Map<String, dynamic> toJson({required String pontoCargaId}) {
    return {
      if (id != null) 'id': id,
      'ponto_carga_id': pontoCargaId,
      'nome': nome,
      'x': _toPerMille(x),
      'y': _toPerMille(y),
      'tamanho': _toPerMille(tamanho),
      if (deslocMax != null) 'desloc_max': deslocMax,
      'descricao': descricao,
      'tipo_elemento': tipoElemento,
    };
  }
}
