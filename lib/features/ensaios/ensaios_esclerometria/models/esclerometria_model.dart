/// Direções de impacto do esclerômetro (define o ângulo salvo em
/// `ponto_ensaio_esclerometria.inclinacao`).
enum DirecaoImpacto {
  horizontal('Horizontal', 0),
  verticalCima('Vertical p/ cima', 90),
  verticalBaixo('Vertical p/ baixo', -90),
  inclinadaCima('Inclinada p/ cima', 45),
  inclinadaBaixo('Inclinada p/ baixo', -45);

  final String label;
  final int graus;
  const DirecaoImpacto(this.label, this.graus);

  static DirecaoImpacto fromGraus(int? graus) {
    return DirecaoImpacto.values.firstWhere(
      (d) => d.graus == graus,
      orElse: () => DirecaoImpacto.horizontal,
    );
  }
}

class EsclerometriaLeituraModel {
  final String? id;
  final int valorQ;
  final String status; // 'aceita' ou 'rejeitada'

  EsclerometriaLeituraModel({
    this.id,
    required this.valorQ,
    required this.status,
  });

  factory EsclerometriaLeituraModel.fromJson(Map<String, dynamic> json) {
    return EsclerometriaLeituraModel(
      id: json['id']?.toString(),
      valorQ: (json['valor_Q'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'rejeitada',
    );
  }

  Map<String, dynamic> toJson(String pontoId) {
    return {
      if (id != null) 'id': id,
      'ponto_id': pontoId,
      'valor_Q': valorQ,
      'status': status,
    };
  }
}

class EsclerometriaCompletoModel {
  final String? idGeral;
  final String? idEsclerometria;
  final String nomePonto;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String criadoEm;
  final String resultado;
  final String resultadoCor;

  final String? urlFotoJanela;
  final String? urlFotoEnsaio;
  final int inclinacao;
  final int indiceK;
  final List<EsclerometriaLeituraModel> leituras;

  EsclerometriaCompletoModel({
    this.idGeral,
    this.idEsclerometria,
    required this.nomePonto,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.criadoEm,
    required this.resultado,
    required this.resultadoCor,
    this.urlFotoJanela,
    this.urlFotoEnsaio,
    this.inclinacao = 0,
    this.indiceK = 1,
    required this.leituras,
  });
}
