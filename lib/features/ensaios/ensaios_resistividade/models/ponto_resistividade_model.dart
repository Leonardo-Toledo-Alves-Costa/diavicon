
class PontoResistividadeLeituraModel {
  final String? id;
  final double resistividade;
  final String hora; 
  final double temperatura;
  double posX;
  double posY;
  final String? dimensao; 
  final String? nomeLeitura;

  PontoResistividadeLeituraModel({
    this.id,
    required this.resistividade,
    required this.hora,
    required this.temperatura,
    required this.posX,
    required this.posY,
    this.dimensao,
    this.nomeLeitura,
    
  });

  factory PontoResistividadeLeituraModel.fromJson(Map<String, dynamic> json) {
    return PontoResistividadeLeituraModel(
      id: json['id'],
      resistividade: (json['resistividade'] as num).toDouble(),
      hora: json['hora'] ?? '',
      temperatura: (json['temperatura'] as num).toDouble(),
      posX: double.tryParse(json['pos_x']?.toString() ?? '0.5') ?? 0.5,
      posY: double.tryParse(json['pos_y']?.toString() ?? '0.5') ?? 0.5,
      nomeLeitura: json['nome_leitura'],
      dimensao: json['dimensao'] ?? '1',
    );
  }

  Map<String, dynamic> toJson(String pontoGeralId) {
    return {
      if (id != null) 'id': id,
      'id_ponto_geral': pontoGeralId,
      'resistividade': resistividade,
      'hora': hora,
      'temperatura': temperatura,
      'pos_x': posX.toString(),
      'pos_y': posY.toString(),
      'nome_leitura': nomeLeitura,
      'dimensao': dimensao,
    };
  }
}

class PontoResistividadeCompletoModel {
  final String? idGeral;
  final String nomePonto;
  final String elementoNome;
  final String tipoElemento;
  final String local;
  final String criadoEm;
  final String resultado;
  final String resultadoCor;
  
  final List<PontoResistividadeLeituraModel> leituras;
  
  final String? urlFotoElemento;
  final String? urlFotoRealizando;
  final String? urlFotoGrid;
  final String? urlFotoGridComPontos;

  PontoResistividadeCompletoModel({
    this.idGeral,
    required this.nomePonto,
    required this.elementoNome,
    required this.tipoElemento,
    required this.local,
    required this.leituras,
    required this.criadoEm,
    required this.resultado,
    required this.resultadoCor,
    this.urlFotoElemento,
    this.urlFotoRealizando,
    this.urlFotoGrid,
    this.urlFotoGridComPontos,
  });
}