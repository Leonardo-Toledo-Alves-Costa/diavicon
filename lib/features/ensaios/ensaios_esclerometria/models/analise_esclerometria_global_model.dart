import 'dart:math';

import 'esclerometria_model.dart' show DirecaoImpacto;

/// Um ponto de esclerometria pra análise global (todos os pontos da
/// estrutura) — réplica das fórmulas de `analise_esclerometria_screen.dart`
/// (única fonte): uma leitura é "aceita" quando seu desvio em relação à
/// média de TODAS as leituras do ponto é <= 10%; "Média Q"/coeficiente de
/// variação só consideram as leituras aceitas.
class AnaliseEsclerometriaGlobalModel {
  final String id;
  final String nomePonto;
  final String local;
  final String nomeElemento;
  final String tipoElemento;
  final int inclinacao;

  final List<int> _todasLeituras;

  AnaliseEsclerometriaGlobalModel({
    required this.id,
    required this.nomePonto,
    required this.local,
    required this.nomeElemento,
    required this.tipoElemento,
    required this.inclinacao,
    required List<int> todasLeituras,
  }) : _todasLeituras = todasLeituras;

  factory AnaliseEsclerometriaGlobalModel.fromMap(Map<String, dynamic> map) {
    final el = map['elementos_estruturais'] as Map<String, dynamic>? ?? const {};
    final escBruto = map['ponto_ensaio_esclerometria'];
    final esc = escBruto is List && escBruto.isNotEmpty
        ? escBruto.first as Map<String, dynamic>
        : (escBruto is Map ? escBruto.cast<String, dynamic>() : null);

    final leiturasResp = esc?['ponto_ensaio_esclerometria_leituras'] as List? ?? const [];
    final todasLeituras = leiturasResp.map((l) => (l['valor_Q'] as num?)?.toInt() ?? 0).toList();

    return AnaliseEsclerometriaGlobalModel(
      id: map['id'].toString(),
      nomePonto: map['nome_ponto']?.toString() ?? 'Ponto',
      local: el['local']?.toString() ?? 'Sem local',
      nomeElemento: el['nome']?.toString() ?? 'Sem nome',
      tipoElemento: el['tipo']?.toString() ?? 'Sem tipo',
      inclinacao: (esc?['inclinacao'] as num?)?.toInt() ?? 0,
      todasLeituras: todasLeituras,
    );
  }

  double get _mediaGeral => _todasLeituras.isEmpty ? 0 : _todasLeituras.reduce((a, b) => a + b) / _todasLeituras.length;

  // Leituras aceitas (desvio <= 10% da média geral do ponto) — já em double
  // pra alimentar direto o boxplot/gráfico.
  List<double> get valoresAceitos {
    final media = _mediaGeral;
    if (media == 0) return const [];
    return _todasLeituras.where((v) => ((v - media) / media).abs() <= 0.10).map((v) => v.toDouble()).toList();
  }

  double get mediaQ {
    final v = valoresAceitos;
    if (v.isEmpty) return 0;
    return v.reduce((a, b) => a + b) / v.length;
  }

  double get coefVariacao {
    final v = valoresAceitos;
    if (v.length < 2) return 0;
    final media = mediaQ;
    if (media == 0) return 0;
    final somaQuad = v.fold<double>(0, (a, x) => a + (x - media) * (x - media));
    final desvio = sqrt(somaQuad / v.length);
    return desvio / media * 100;
  }

  int get quantidadeAceitas => valoresAceitos.length;

  String get direcaoImpacto => DirecaoImpacto.fromGraus(inclinacao).label;
}
