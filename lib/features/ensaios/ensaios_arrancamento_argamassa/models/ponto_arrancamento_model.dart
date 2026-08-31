import 'dart:math';

class PontoArrancamentoModel {
  final String? id; // ponto_ensaio_arrancamento ID
  final String? pontoEnsaioId; // pontos_ensaios_geral ID
  final String? imagemRegiao;
  final String? imagemColagem;
  final String norma;
  final String? eqpUtilizado;
  final String? tipoSubstrato;
  final String? temperatura;
  final String? umidade;
  final String? idadeRevestimento;
  final String? colaUtilizada;
  final List<PontoArrancamentoLeituraModel> leituras;

  PontoArrancamentoModel({
    this.id,
    this.pontoEnsaioId,
    this.imagemRegiao,
    this.imagemColagem,
    this.norma = 'ABNT NBR 13525-2:2019',
    this.eqpUtilizado,
    this.tipoSubstrato,
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
    final variance = validas
            .map((x) => pow(x.tensaoCalculada - m, 2))
            .reduce((a, b) => a + b) /
        validas.length;
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
      'tipo_substrato': tipoSubstrato,
    };
  }

  factory PontoArrancamentoModel.fromMap(
    Map<String, dynamic> map, {
    List<PontoArrancamentoLeituraModel> leituras = const [],
  }) {
    return PontoArrancamentoModel(
      id: map['id'] as String?,
      pontoEnsaioId: map['ponto_ensaio_id'] as String?,
      imagemRegiao: map['imagem_regiao'] as String?,
      imagemColagem: map['imagem_colagem'] as String?,
      norma: map['norma'] as String? ?? 'ABNT NBR 13525-2:2019',
      eqpUtilizado: map['eqp_utilizado'] as String?,
      temperatura: map['temperatura'] as String?,
      umidade: map['umidade'] as String?,
      idadeRevestimento: map['idade_revestimento'] as String?,
      colaUtilizada: map['cola_utilizada'] as String?,
      tipoSubstrato: map['tipo_substrato'],
      leituras: leituras,
    );
  }
}

class PontoArrancamentoLeituraModel {
  final String? id;
  final String? idPontoArrancamento;
  final String nome;
  final String? imagemEnsaio;
  final String? imagemRuptura;
  final double? d1;
  final double? d2;
  final double? area;
  final double? carga;
  final List<PontoArrancamentoRupturaModel> rupturas;

  PontoArrancamentoLeituraModel({
    this.id,
    this.idPontoArrancamento,
    required this.nome,
    this.imagemEnsaio,
    this.imagemRuptura,
    this.d1,
    this.d2,
    this.area,
    this.carga,
    this.rupturas = const [],
  });

  double get diametroMedio {
    if (d1 != null && d2 != null && d1! > 0 && d2! > 0) {
      return (d1! + d2!) / 2.0;
    } else if (d1 != null && d1! > 0) {
      return d1!;
    }
    return 0.0;
  }

  double get areaCalculada {
    if (area != null && area! > 0) return area!;
    final dm = diametroMedio;
    if (dm <= 0) return 0.0;
    return pi * pow(dm / 2.0, 2);
  }

  double get tensaoCalculada {
    final a = areaCalculada;
    if (a <= 0 || carga == null || carga! <= 0) return 0.0;
    return carga! / a; // N/mm² = MPa
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
      'd1': d1,
      'd2': d2,
      'area': areaCalculada,
      'carga': carga,
    };
  }

  factory PontoArrancamentoLeituraModel.fromMap(
    Map<String, dynamic> map, {
    List<PontoArrancamentoRupturaModel> rupturas = const [],
  }) {
    return PontoArrancamentoLeituraModel(
      id: map['id'] as String?,
      idPontoArrancamento: map['id_ponto_arrancamento'] as String?,
      nome: map['nome'] as String? ?? 'P1',
      imagemEnsaio: map['imagem_ensaio'] as String?,
      imagemRuptura: map['imgem_ruptura'] as String?,
      d1: (map['d1'] as num?)?.toDouble(),
      d2: (map['d2'] as num?)?.toDouble(),
      area: (map['area'] as num?)?.toDouble(),
      carga: (map['carga'] as num?)?.toDouble(),
      rupturas: rupturas,
    );
  }
}

class PontoArrancamentoRupturaModel {
  final String? id;
  final String? idPontoLeitura;
  final String tipoRuptura;
  final double porcentagem;

  PontoArrancamentoRupturaModel({
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

  factory PontoArrancamentoRupturaModel.fromMap(Map<String, dynamic> map) {
    return PontoArrancamentoRupturaModel(
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

class CatalogoRupturas {
  static const List<TipoRupturaCatalogoItem> itens = [
    TipoRupturaCatalogoItem(
      id: 'substrato',
      titulo: 'Substrato',
      sigla: 'S',
      assetPath: 'assets/images/ensaios/arrancamento/substrato.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'substrato_argamassa',
      titulo: 'Substrato / Argamassa',
      sigla: 'S/A',
      assetPath: 'assets/images/ensaios/arrancamento/substrato-argamassa.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'argamassa',
      titulo: 'Argamassa',
      sigla: 'A',
      assetPath: 'assets/images/ensaios/arrancamento/argamassa.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'falha_cola',
      titulo: 'Falha na Cola',
      sigla: 'F',
      assetPath: 'assets/images/ensaios/arrancamento/argamassa-pastilha.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'substrato_chapisco',
      titulo: 'Substrato / Chapisco',
      sigla: 'S/C',
      assetPath: 'assets/images/ensaios/arrancamento/substrato-chapisco.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'chapisco',
      titulo: 'Chapisco',
      sigla: 'C',
      assetPath: 'assets/images/ensaios/arrancamento/chapisco.png',
    ),
    TipoRupturaCatalogoItem(
      id: 'chapisco_argamassa',
      titulo: 'Chapisco / Argamassa',
      sigla: 'C/A',
      assetPath: 'assets/images/ensaios/arrancamento/chapisco-argamassa.png',
    ),
  ];
}