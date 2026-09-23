import 'dart:math';

import 'package:flutter/material.dart';

/// Classificação da qualidade do concreto pela velocidade do pulso
/// ultrassônico, segundo Whitehurst — mesma tabela mostrada no popup de
/// ajuda da tela de coleta.
class ClassificacaoWhitehurst {
  final String texto;
  final Color cor;
  final String hex;
  const ClassificacaoWhitehurst({required this.texto, required this.cor, required this.hex});

  static ClassificacaoWhitehurst classificar(double velocidade) {
    if (velocidade <= 0) return const ClassificacaoWhitehurst(texto: 'Pendente', cor: Colors.grey, hex: '#BDBDBD');
    if (velocidade > 4500) return const ClassificacaoWhitehurst(texto: 'Excelente', cor: Color(0xFF2E7D32), hex: '#2E7D32');
    if (velocidade > 3500) return const ClassificacaoWhitehurst(texto: 'Ótimo', cor: Color(0xFF66BB6A), hex: '#66BB6A');
    if (velocidade > 3000) return const ClassificacaoWhitehurst(texto: 'Bom', cor: Color(0xFFFBC02D), hex: '#FBC02D');
    if (velocidade > 2000) return const ClassificacaoWhitehurst(texto: 'Regular', cor: Color(0xFFFF9800), hex: '#FF9800');
    return const ClassificacaoWhitehurst(texto: 'Ruim', cor: Color(0xFFE53935), hex: '#E53935');
  }

  // Referência completa da tabela, pro popup de ajuda.
  static const List<({String faixa, String classe})> tabela = [
    (faixa: 'V > 4500 m/s', classe: 'Excelente'),
    (faixa: '3500 < V < 4500 m/s', classe: 'Ótimo'),
    (faixa: '3000 < V < 3500 m/s', classe: 'Bom'),
    (faixa: '2000 < V < 3000 m/s', classe: 'Regular'),
    (faixa: 'V < 2000 m/s', classe: 'Ruim'),
  ];
}

/// Uma leitura de velocidade dentro de um ponto de medição
/// (`ponto_ensaio_ultrassom_direto_leitura`). A FK pra medição se chama
/// `ponto_id` no banco (não `id_medicao`), e `velocidade` é `bigint` —
/// arredondamos ao serializar.
class LeituraUltrassomDiretoModel {
  final String? id;
  final String? idMedicao;
  double velocidade;

  LeituraUltrassomDiretoModel({this.id, this.idMedicao, required this.velocidade});

  factory LeituraUltrassomDiretoModel.fromJson(Map<String, dynamic> json) {
    return LeituraUltrassomDiretoModel(
      id: json['id']?.toString(),
      idMedicao: json['ponto_id']?.toString(),
      velocidade: (json['velocidade'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson(String idMedicao) {
    return {
      if (id != null) 'id': id,
      'ponto_id': idMedicao,
      'velocidade': velocidade.round(),
    };
  }
}

/// Um ponto de medição marcado na foto (transdutores posicionados) —
/// `ponto_ensaio_ultrassom_direto_medicao`. Cada um pode ter N leituras.
class PontoMedicaoUltrassomDiretoModel {
  final String? id;
  final String? idUltrassom;
  String nomePonto;
  double? distancia; // distância entre os transdutores (cm)
  double posX;
  double posY;
  List<LeituraUltrassomDiretoModel> leituras;

  PontoMedicaoUltrassomDiretoModel({
    this.id,
    this.idUltrassom,
    required this.nomePonto,
    this.distancia,
    required this.posX,
    required this.posY,
    this.leituras = const [],
  });

  double get media {
    if (leituras.isEmpty) return 0.0;
    final soma = leituras.fold<double>(0, (a, l) => a + l.velocidade);
    return soma / leituras.length;
  }

  double get coefVariacao {
    if (leituras.length < 2) return 0.0;
    final m = media;
    if (m == 0) return 0.0;
    final somaQuad = leituras.fold<double>(0, (a, l) => a + (l.velocidade - m) * (l.velocidade - m));
    final desvio = sqrt(somaQuad / leituras.length);
    return (desvio / m) * 100;
  }

  factory PontoMedicaoUltrassomDiretoModel.fromJson(
    Map<String, dynamic> json, {
    List<LeituraUltrassomDiretoModel> leituras = const [],
  }) {
    return PontoMedicaoUltrassomDiretoModel(
      id: json['id']?.toString(),
      idUltrassom: json['ponto_id']?.toString(),
      nomePonto: json['nome_ponto']?.toString() ?? 'Ponto',
      distancia: (json['distancia'] as num?)?.toDouble(),
      // `pox_x` é o nome literal da coluna no banco (typo já existente no
      // schema) — e tanto ela quanto `pos_y` são `text`, não numéricas.
      posX: double.tryParse(json['pox_x']?.toString() ?? '') ?? 0.5,
      posY: double.tryParse(json['pos_y']?.toString() ?? '') ?? 0.5,
      leituras: leituras,
    );
  }

  Map<String, dynamic> toJson(String idUltrassom) {
    return {
      if (id != null) 'id': id,
      'ponto_id': idUltrassom,
      'nome_ponto': nomePonto,
      'distancia': distancia?.round(),
      'pox_x': posX.toString(),
      'pos_y': posY.toString(),
    };
  }
}

/// A "Área de Ensaio" da Ultrassonografia — modo Direto — 1 por ponto geral
/// (`ponto_ensaio_ultrassom`, `modo = 'direto'`).
class PontoUltrassomDiretoModel {
  final String? id;
  final String? pontoGeralId;
  final String pulsoUltrassonico; // 'Longitudinal' | 'Transversal' — coluna real: tipo_onda
  final String? foto1; // marcação da área
  final String? foto2; // realização do ensaio
  final String? foto3; // imagem com os pontos de leitura marcados
  final List<PontoMedicaoUltrassomDiretoModel> medicoes;

  /// Importação do equipamento (web app) que gerou este ponto, se houver.
  /// Só leitura: quem grava é a própria importação.
  final String? importacaoId;

  const PontoUltrassomDiretoModel({
    this.id,
    this.pontoGeralId,
    this.pulsoUltrassonico = 'Longitudinal',
    this.foto1,
    this.foto2,
    this.foto3,
    this.medicoes = const [],
    this.importacaoId,
  });

  // Média das médias de cada ponto de medição (cada ponto pesa igual,
  // independente de quantas leituras tenha) — usada como `valor_resultado`
  // de `pontos_ensaios_geral`.
  double get mediaGeral {
    final medias = medicoes.map((m) => m.media).where((m) => m > 0).toList();
    if (medias.isEmpty) return 0.0;
    return medias.reduce((a, b) => a + b) / medias.length;
  }

  double get coefVariacaoGeral {
    final medias = medicoes.map((m) => m.media).where((m) => m > 0).toList();
    if (medias.length < 2) return 0.0;
    final m = mediaGeral;
    if (m == 0) return 0.0;
    final somaQuad = medias.fold<double>(0, (a, v) => a + (v - m) * (v - m));
    final desvio = sqrt(somaQuad / medias.length);
    return (desvio / m) * 100;
  }

  factory PontoUltrassomDiretoModel.fromJson(
    Map<String, dynamic> json, {
    List<PontoMedicaoUltrassomDiretoModel> medicoes = const [],
  }) {
    return PontoUltrassomDiretoModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_ensaio_id']?.toString(),
      pulsoUltrassonico: json['tipo_onda']?.toString() ?? 'Longitudinal',
      foto1: json['foto_1']?.toString(),
      foto2: json['foto_2']?.toString(),
      foto3: json['foto_3']?.toString(),
      medicoes: medicoes,
      importacaoId: json['importacao_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson({required String pontoEnsaioId}) {
    return {
      if (id != null) 'id': id,
      'ponto_ensaio_id': pontoEnsaioId,
      'modo': 'direto',
      'tipo_onda': pulsoUltrassonico,
      if (foto1 != null) 'foto_1': foto1,
      if (foto2 != null) 'foto_2': foto2,
      if (foto3 != null) 'foto_3': foto3,
    };
  }

  PontoUltrassomDiretoModel copyWith({
    String? id,
    String? pontoGeralId,
    String? pulsoUltrassonico,
    String? foto1,
    String? foto2,
    String? foto3,
    List<PontoMedicaoUltrassomDiretoModel>? medicoes,
  }) {
    return PontoUltrassomDiretoModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      pulsoUltrassonico: pulsoUltrassonico ?? this.pulsoUltrassonico,
      foto1: foto1 ?? this.foto1,
      foto2: foto2 ?? this.foto2,
      foto3: foto3 ?? this.foto3,
      medicoes: medicoes ?? this.medicoes,
      importacaoId: importacaoId,
    );
  }
}
