import 'package:flutter/material.dart';

/// Etapa de uma leitura — carregamento e descarregamento são duas séries
/// separadas no gráfico força × deslocamento (mesma curva, cores diferentes).
enum EtapaLeituraChumbador {
  carregamento('carregamento', 'Carregamento', Color(0xFF1E88E5)),
  descarregamento('descarregamento', 'Descarregamento', Color(0xFFFB8C00));

  final String chave;
  final String label;
  final Color cor;
  const EtapaLeituraChumbador(this.chave, this.label, this.cor);

  static EtapaLeituraChumbador fromChave(String? chave) {
    return EtapaLeituraChumbador.values.firstWhere((e) => e.chave == chave, orElse: () => EtapaLeituraChumbador.carregamento);
  }
}

/// Condição de avaliação — seleção manual do inspetor (Aprovado/Reprovado/
/// Cabe análise), nunca calculada automaticamente (ver regra de negócio do
/// prompt original: nenhuma sugestão automática na v1).
enum CondicaoAvaliacaoChumbador {
  aprovado('aprovado', 'Aprovado', Color(0xFF4CAF50)),
  reprovado('reprovado', 'Reprovado', Color(0xFFF44336)),
  cabeAnalise('cabe_analise', 'Cabe análise', Color(0xFF9E9E9E));

  final String chave;
  final String label;
  final Color cor;
  const CondicaoAvaliacaoChumbador(this.chave, this.label, this.cor);

  static CondicaoAvaliacaoChumbador? fromChave(String? chave) {
    if (chave == null || chave.isEmpty) return null;
    return CondicaoAvaliacaoChumbador.values.firstWhere((c) => c.chave == chave, orElse: () => CondicaoAvaliacaoChumbador.cabeAnalise);
  }
}

/// Uma leitura — `ponto_ensaio_tracao_leitura`. A tabela real não tem uma
/// coluna de número/ordem manual (diferente do prompt original) — as
/// curvas do gráfico são ordenadas por `criado_em` (ordem de inserção).
class LeituraChumbadorModel {
  final String? id;
  final String? ensaioId;
  final DateTime? criadoEm;
  final EtapaLeituraChumbador etapa;
  final double forcaKn;
  final double deslocamentoMm;
  final String? foto;
  final String ocorrencia;

  const LeituraChumbadorModel({
    this.id,
    this.ensaioId,
    this.criadoEm,
    required this.etapa,
    required this.forcaKn,
    required this.deslocamentoMm,
    this.foto,
    this.ocorrencia = '',
  });

  factory LeituraChumbadorModel.fromJson(Map<String, dynamic> json) {
    return LeituraChumbadorModel(
      id: json['id']?.toString(),
      ensaioId: json['ponto_id']?.toString(),
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
      etapa: EtapaLeituraChumbador.fromChave(json['etapa']?.toString()),
      forcaKn: double.tryParse(json['carga']?.toString() ?? '') ?? 0,
      deslocamentoMm: double.tryParse(json['deslocamento']?.toString() ?? '') ?? 0,
      foto: json['foto']?.toString(),
      ocorrencia: json['ocorrencia']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson(String ensaioId) {
    return {
      if (id != null) 'id': id,
      'ponto_id': ensaioId,
      'etapa': etapa.chave,
      'carga': forcaKn.toString(),
      'deslocamento': deslocamentoMm.toString(),
      if (foto != null) 'foto': foto,
      'ocorrencia': ocorrencia,
    };
  }
}

/// O ensaio — `ponto_ensaio_tracao` — 1 por ponto geral (1 chumbador
/// testado = 1 elemento, ver hierarquia padrão do app).
class ChumbadorModel {
  final String? id;
  final String? pontoGeralId;
  final String? fotoChumbador;
  final String? fotoDurante;
  final String? fotoApos;
  final String ocorrenciasGerais;
  final CondicaoAvaliacaoChumbador? condicaoAvaliacao;
  final List<LeituraChumbadorModel> leituras;

  const ChumbadorModel({
    this.id,
    this.pontoGeralId,
    this.fotoChumbador,
    this.fotoDurante,
    this.fotoApos,
    this.ocorrenciasGerais = '',
    this.condicaoAvaliacao,
    this.leituras = const [],
  });

  // Ordenadas por `criado_em` — a tabela real não tem um número de leitura
  // manual (ver comentário em `LeituraChumbadorModel`).
  List<LeituraChumbadorModel> get leiturasOrdenadas {
    final lista = [...leituras];
    lista.sort((a, b) => (a.criadoEm ?? DateTime(0)).compareTo(b.criadoEm ?? DateTime(0)));
    return lista;
  }

  List<LeituraChumbadorModel> get leiturasCarregamento =>
      leiturasOrdenadas.where((l) => l.etapa == EtapaLeituraChumbador.carregamento).toList();

  List<LeituraChumbadorModel> get leiturasDescarregamento =>
      leiturasOrdenadas.where((l) => l.etapa == EtapaLeituraChumbador.descarregamento).toList();

  // Carga máxima = maior força entre as leituras de CARREGAMENTO.
  double? get cargaMaxima {
    final carregamento = leiturasCarregamento;
    if (carregamento.isEmpty) return null;
    return carregamento.map((l) => l.forcaKn).reduce((a, b) => a > b ? a : b);
  }

  // Deslocamento máximo = o deslocamento DA LEITURA DE PICO (onde ocorreu a
  // carga máxima), não o maior deslocamento isolado do ensaio — evita pegar
  // deformação residual do descarregamento por engano (ver regra de negócio
  // do prompt original).
  double? get deslocamentoMaximo {
    final carregamento = leiturasCarregamento;
    if (carregamento.isEmpty) return null;
    final pico = carregamento.reduce((a, b) => b.forcaKn > a.forcaKn ? b : a);
    return pico.deslocamentoMm;
  }

  factory ChumbadorModel.fromJson(Map<String, dynamic> json, {List<LeituraChumbadorModel> leituras = const []}) {
    return ChumbadorModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_id']?.toString(),
      fotoChumbador: json['foto_antes']?.toString(),
      fotoDurante: json['foto_durante']?.toString(),
      fotoApos: json['foto_apos']?.toString(),
      ocorrenciasGerais: json['ocorrencia_geral']?.toString() ?? '',
      condicaoAvaliacao: CondicaoAvaliacaoChumbador.fromChave(json['cond_avaliar']?.toString()),
      leituras: leituras,
    );
  }

  Map<String, dynamic> toJson({required String pontoGeralId}) {
    return {
      if (id != null) 'id': id,
      'ponto_id': pontoGeralId,
      if (fotoChumbador != null) 'foto_antes': fotoChumbador,
      if (fotoDurante != null) 'foto_durante': fotoDurante,
      if (fotoApos != null) 'foto_apos': fotoApos,
      'ocorrencia_geral': ocorrenciasGerais,
      'cond_avaliar': condicaoAvaliacao?.chave,
      'carga_max': cargaMaxima?.toString(),
      'desloc_max': deslocamentoMaximo?.toString(),
    };
  }

  ChumbadorModel copyWith({
    String? id,
    String? pontoGeralId,
    String? fotoChumbador,
    String? fotoDurante,
    String? fotoApos,
    String? ocorrenciasGerais,
    CondicaoAvaliacaoChumbador? condicaoAvaliacao,
    bool limparCondicaoAvaliacao = false,
    List<LeituraChumbadorModel>? leituras,
  }) {
    return ChumbadorModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      fotoChumbador: fotoChumbador ?? this.fotoChumbador,
      fotoDurante: fotoDurante ?? this.fotoDurante,
      fotoApos: fotoApos ?? this.fotoApos,
      ocorrenciasGerais: ocorrenciasGerais ?? this.ocorrenciasGerais,
      condicaoAvaliacao: limparCondicaoAvaliacao ? null : (condicaoAvaliacao ?? this.condicaoAvaliacao),
      leituras: leituras ?? this.leituras,
    );
  }
}
