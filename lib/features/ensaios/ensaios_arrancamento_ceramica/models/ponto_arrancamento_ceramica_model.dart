import 'dart:math';

class PontoArrancamentoCeramicaModel {
  final String? id; 
  final String? pontoEnsaioId; 
  final String? imagemRegiao;
  final String? imagemColagem;
  final String norma;
  final String? eqpUtilizado;
  final String? temperatura;
  final String? umidade;
  final String? idadeRevestimento;
  final String? colaUtilizada;
  final List<PontoLeituraCeramicaModel> leituras;

  PontoArrancamentoCeramicaModel({
    this.id,
    this.pontoEnsaioId,
    this.imagemRegiao,
    this.imagemColagem,
    this.norma = '1481-4',
    this.eqpUtilizado,
    this.temperatura,
    this.umidade,
    this.idadeRevestimento,
    this.colaUtilizada,
    this.leituras = const [],
  });

  double get mediaTensao {
    final validas = leituras.where((l) => l.tensaoCalculada > 0).toList();
    if (validas.isEmpty) return 0.0;
    final soma = validas.fold(0.0, (acc, item) => acc + item.tensaoCalculada);
    return soma / validas.length;
  }

  double get coefVariacao {
    final validas = leituras.where((l) => l.tensaoCalculada > 0).toList();
    if (validas.length <= 1) return 0.0;
    final m = mediaTensao;
    if (m == 0) return 0.0;
    final variance = validas.map((x) => pow(x.tensaoCalculada - m, 2)).reduce((a, b) => a + b) / validas.length;
    final stdDev = sqrt(variance);
    return (stdDev / m) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (pontoEnsaioId != null) 'ponto_ensaio_id': pontoEnsaioId,
      'imagem_regiao': imagemRegiao,
      'imagem_colagem': imagemColagem,
      'norma': norma,
      'eqp_utilizado': eqpUtilizado,
      'temperatura': temperatura,
      'umidade': umidade,
      'idade_revestimento': idadeRevestimento,
      'cola_utilizada': colaUtilizada,
    };
  }

  factory PontoArrancamentoCeramicaModel.fromMap(
    Map<String, dynamic> map, {
    List<PontoLeituraCeramicaModel> leituras = const [],
  }) {
    return PontoArrancamentoCeramicaModel(
      id: map['id'] as String?,
      pontoEnsaioId: map['ponto_ensaio_id'] as String?,
      imagemRegiao: map['imagem_regiao'] as String?,
      imagemColagem: map['imagem_colagem'] as String?,
      norma: map['norma'] as String? ?? '1481-4',
      eqpUtilizado: map['eqp_utilizado'] as String?,
      temperatura: map['temperatura'] as String?,
      umidade: map['umidade'] as String?,
      idadeRevestimento: map['idade_revestimento'] as String?,
      colaUtilizada: map['cola_utilizada'] as String?,
      leituras: leituras,
    );
  }
}

class PontoLeituraCeramicaModel {
  final String? id;
  final String? idPontoArrancamento;
  final String nome;
  final String? imagemEnsaio;
  final String? imagemRuptura;
  final double? area;
  final double? carga;
  final List<RupturaCeramicaModel> rupturas;

  PontoLeituraCeramicaModel({
    this.id,
    this.idPontoArrancamento,
    required this.nome,
    this.imagemEnsaio,
    this.imagemRuptura,
    this.area,
    this.carga,
    this.rupturas = const [],
  });

  double get tensaoCalculada {
    if (area == null || area! <= 0 || carga == null || carga! <= 0) return 0.0;
    return carga! / area!; // N/mm² = MPa
  }

  String get resumoRupturas {
    final preenchidas = rupturas.where((r) => r.porcentagem > 0).toList();
    if (preenchidas.isEmpty) return 'Não definida';
    return preenchidas.map((r) => '${r.porcentagem.toStringAsFixed(0)}% ${r.tipoRuptura}').join(' | ');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (idPontoArrancamento != null) 'id_ponto_arrancamento': idPontoArrancamento,
      'nome': nome,
      'imagem_ensaio': imagemEnsaio,
      'imgem_ruptura': imagemRuptura,
      'area': area,
      'carga': carga,
    };
  }

  factory PontoLeituraCeramicaModel.fromMap(
    Map<String, dynamic> map, {
    List<RupturaCeramicaModel> rupturas = const [],
  }) {
    return PontoLeituraCeramicaModel(
      id: map['id'] as String?,
      idPontoArrancamento: map['id_ponto_arrancamento'] as String?,
      nome: map['nome'] as String? ?? 'P1',
      imagemEnsaio: map['imagem_ensaio'] as String?,
      imagemRuptura: map['imgem_ruptura'] as String?,
      area: (map['area'] as num?)?.toDouble(),
      carga: (map['carga'] as num?)?.toDouble(),
      rupturas: rupturas,
    );
  }
}

class RupturaCeramicaModel {
  final String? id;
  final String? idPontoLeitura;
  final String tipoRuptura;
  final double porcentagem;

  RupturaCeramicaModel({
    this.id,
    this.idPontoLeitura,
    required this.tipoRuptura,
    required this.porcentagem,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (idPontoLeitura != null) 'id_ponto_leitura': idPontoLeitura,
      'tipo_ruptura': tipoRuptura,
      'porcentagem': porcentagem,
    };
  }

  factory RupturaCeramicaModel.fromMap(Map<String, dynamic> map) {
    return RupturaCeramicaModel(
      id: map['id'] as String?,
      idPontoLeitura: map['id_ponto_leitura'] as String?,
      tipoRuptura: map['tipo_ruptura'] as String? ?? '',
      porcentagem: (map['porcentagem'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TipoRupturaCatalogoItem {
  final String id;
  final String titulo;
  final String sigla;
  final String assetPath;

  const TipoRupturaCatalogoItem({
    required this.id,
    required this.titulo,
    required this.sigla,
    required this.assetPath,
  });
}

// Catálogo exclusivo para Placa Cerâmica
class CatalogoRupturasCeramica {
  static const List<TipoRupturaCatalogoItem> itens = [
    TipoRupturaCatalogoItem(id: 'substrato', 
                            titulo: 'Substrato', 
                            sigla: 'S', 
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/substrato.png'),
    TipoRupturaCatalogoItem(id: 'argamassa-substrato', 
                            titulo: 'Argamassa / Substrato', 
                            sigla: 'S / A', 
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/substrato-argamassa.png'),
    TipoRupturaCatalogoItem(id: 'argamassa', 
                            titulo: 'Argamassa', 
                            sigla: 'A', 
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/argamassa.png'),
    TipoRupturaCatalogoItem(id: 'argamassa-ceramica', 
                            titulo: 'Argamassa / Cerâmica', 
                            sigla: 'A / C',
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/argamassa-ceramica.png'),
    TipoRupturaCatalogoItem(id: 'ceramica', 
                            titulo: 'Cerâmica', 
                            sigla: 'C', 
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/ceramica.png'),
    TipoRupturaCatalogoItem(id: 'falha', 
                            titulo: 'Falha na colagem', 
                            sigla: 'F', 
                            assetPath: 'assets/images/ensaios/arrancamento_ceramica/falha.png'),
  ];
}