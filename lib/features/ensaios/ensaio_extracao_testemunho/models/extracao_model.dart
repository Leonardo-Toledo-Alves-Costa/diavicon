import '../utils/extracao_math.dart';

/// Direção da extração do testemunho — fator k3 da correção de resistência.
enum DirecaoExtracao {
  paralelo('paralelo', 'Paralelo'),
  perpendicular('perpendicular', 'Perpendicular');

  final String chave;
  final String label;
  const DirecaoExtracao(this.chave, this.label);

  static DirecaoExtracao fromChave(String? chave) {
    return DirecaoExtracao.values.firstWhere((d) => d.chave == chave, orElse: () => DirecaoExtracao.paralelo);
  }
}

/// Condição de umidade do testemunho no rompimento — fator k4.
enum CondicaoUmidade {
  saturado('saturado', 'Saturado'),
  secoAoAr('seco_ao_ar', 'Seco ao ar');

  final String chave;
  final String label;
  const CondicaoUmidade(this.chave, this.label);

  static CondicaoUmidade fromChave(String? chave) {
    return CondicaoUmidade.values.firstWhere((c) => c.chave == chave, orElse: () => CondicaoUmidade.secoAoAr);
  }
}

/// Um testemunho extraído — `ponto_ensaio_extracao_leituras`. Cada um é
/// vinculado a um elemento estrutural específico (diferente dos demais
/// campos deste ensaio, que são por Local — ver `ExtracaoLocalModel`).
///
/// `resistenciaComCorrecao` é SEMPRE calculada (ver `ExtracaoMath`, fórmula
/// da ABNT NBR 7680-1:2015, Seção 6.2) — nunca lida do banco como valor
/// próprio; a coluna `resistencia_corrigida` só guarda esse cálculo como
/// cache (pra aparecer em queries agregadas sem juntar os 4 fatores).
class LeituraExtracaoModel {
  final String? id;
  final String? pontoLocalId;
  final String? elementoId;
  final String elementoNome; // só leitura, resolvido via join — não persistido aqui
  final String tipoElemento; // idem
  final DateTime? criadoEm;
  final String nomeTestemunho;
  final double posX; // fração 0-1 da largura da planta
  final double posY; // fração 0-1 da altura da planta
  final String? fotoExtraindo; // foto_ext — durante a extração
  final String? fotoExtracao; // foto_cp — o corpo de prova extraído
  final String? fotoRecomposicao; // foto_rcp
  final String? fotoPlanta; // foto_planta — planta marcada com esse ponto em destaque
  final DirecaoExtracao direcao;
  final double relacaoHD; // k1 (relação h/d bruta — não o coeficiente resolvido)
  final double diametroTestemunho; // k2 (diâmetro em mm — não o coeficiente resolvido)
  final CondicaoUmidade condicaoUmidade;
  final double resistenciaSemCorrecao;

  const LeituraExtracaoModel({
    this.id,
    this.pontoLocalId,
    this.elementoId,
    this.elementoNome = '',
    this.tipoElemento = '',
    this.criadoEm,
    required this.nomeTestemunho,
    required this.posX,
    required this.posY,
    this.fotoExtraindo,
    this.fotoExtracao,
    this.fotoRecomposicao,
    this.fotoPlanta,
    this.direcao = DirecaoExtracao.paralelo,
    this.relacaoHD = 2.0,
    this.diametroTestemunho = 100,
    this.condicaoUmidade = CondicaoUmidade.secoAoAr,
    required this.resistenciaSemCorrecao,
  });

  // ABNT NBR 7680-1:2015 — null quando o diâmetro não é permitido (<50 mm).
  double? get resistenciaComCorrecao => ExtracaoMath.resistenciaCorrigida(
        resistenciaSemCorrecao: resistenciaSemCorrecao,
        relacaoHD: relacaoHD,
        diametroTestemunho: diametroTestemunho,
        direcao: direcao,
        umidade: condicaoUmidade,
      );

  factory LeituraExtracaoModel.fromJson(Map<String, dynamic> json) {
    final elemento = json['elementos_estruturais'] as Map<String, dynamic>?;
    return LeituraExtracaoModel(
      id: json['id']?.toString(),
      pontoLocalId: json['ponto_local_id']?.toString(),
      elementoId: json['elemento_id']?.toString(),
      elementoNome: elemento?['nome']?.toString() ?? '',
      tipoElemento: elemento?['tipo']?.toString() ?? '',
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? ''),
      nomeTestemunho: json['nome_testemunho']?.toString() ?? '',
      posX: double.tryParse(json['p_x']?.toString() ?? '') ?? 0.5,
      posY: double.tryParse(json['p_y']?.toString() ?? '') ?? 0.5,
      fotoExtraindo: json['foto_ext']?.toString(),
      fotoExtracao: json['foto_cp']?.toString(),
      fotoRecomposicao: json['foto_rcp']?.toString(),
      fotoPlanta: json['foto_planta']?.toString(),
      direcao: DirecaoExtracao.fromChave(json['k3']?.toString()),
      relacaoHD: double.tryParse(json['k1']?.toString() ?? '') ?? 2.0,
      diametroTestemunho: double.tryParse(json['k2']?.toString() ?? '') ?? 100,
      condicaoUmidade: CondicaoUmidade.fromChave(json['k4']?.toString()),
      resistenciaSemCorrecao: double.tryParse(json['resistencia']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson(String pontoLocalId) {
    return {
      if (id != null) 'id': id,
      'ponto_local_id': pontoLocalId,
      'elemento_id': elementoId,
      'nome_testemunho': nomeTestemunho,
      'p_x': posX.toString(),
      'p_y': posY.toString(),
      if (fotoExtraindo != null) 'foto_ext': fotoExtraindo,
      if (fotoExtracao != null) 'foto_cp': fotoExtracao,
      if (fotoRecomposicao != null) 'foto_rcp': fotoRecomposicao,
      if (fotoPlanta != null) 'foto_planta': fotoPlanta,
      'k3': direcao.chave,
      'k1': relacaoHD.toString(),
      'k2': diametroTestemunho.toString(),
      'k4': condicaoUmidade.chave,
      'resistencia': resistenciaSemCorrecao.toString(),
      'resistencia_corrigida': resistenciaComCorrecao?.toString(),
    };
  }
}

/// O ensaio — `ponto_ensaio_extracao_local` — 1 por Local (não por
/// elemento, ver contexto do prompt original: "feito por local ou
/// estrutura, com múltiplos pontos de extração espalhados").
class ExtracaoLocalModel {
  final String? id;
  final String? pontoGeralId;
  final String? localId;
  final String? plantaId;
  final String? plantaMarcada; // imagem composta (planta + TODOS os pontos), se gerada
  final List<LeituraExtracaoModel> leituras;

  const ExtracaoLocalModel({
    this.id,
    this.pontoGeralId,
    this.localId,
    this.plantaId,
    this.plantaMarcada,
    this.leituras = const [],
  });

  // Ordenados por `criado_em` — a numeração visual (P1, P2, P3...) é a
  // posição nessa lista, não uma coluna própria (a tabela real não tem uma).
  List<LeituraExtracaoModel> get leiturasOrdenadas {
    final lista = [...leituras];
    lista.sort((a, b) => (a.criadoEm ?? DateTime(0)).compareTo(b.criadoEm ?? DateTime(0)));
    return lista;
  }

  factory ExtracaoLocalModel.fromJson(Map<String, dynamic> json, {List<LeituraExtracaoModel> leituras = const []}) {
    return ExtracaoLocalModel(
      id: json['id']?.toString(),
      pontoGeralId: json['ponto_id']?.toString(),
      localId: json['local_id']?.toString(),
      plantaId: json['planta_id']?.toString(),
      plantaMarcada: json['planta_marcada']?.toString(),
      leituras: leituras,
    );
  }

  Map<String, dynamic> toJson({required String pontoGeralId}) {
    return {
      if (id != null) 'id': id,
      'ponto_id': pontoGeralId,
      'local_id': localId,
      'planta_id': plantaId,
      if (plantaMarcada != null) 'planta_marcada': plantaMarcada,
    };
  }

  ExtracaoLocalModel copyWith({
    String? id,
    String? pontoGeralId,
    String? localId,
    String? plantaId,
    String? plantaMarcada,
    List<LeituraExtracaoModel>? leituras,
  }) {
    return ExtracaoLocalModel(
      id: id ?? this.id,
      pontoGeralId: pontoGeralId ?? this.pontoGeralId,
      localId: localId ?? this.localId,
      plantaId: plantaId ?? this.plantaId,
      plantaMarcada: plantaMarcada ?? this.plantaMarcada,
      leituras: leituras ?? this.leituras,
    );
  }
}
