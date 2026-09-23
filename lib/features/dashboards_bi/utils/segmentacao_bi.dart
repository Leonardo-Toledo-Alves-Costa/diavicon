import 'package:flutter/material.dart';

import '../../../core/models/classe_qualitativa.dart';
import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../repositories/dashboard_bi_repository.dart';
import 'classificadores_bi.dart';

/// Uma escala qualitativa usável para segmentar uma barra: classifica UM
/// valor numérico. Vem dos badges de uma entrada só (Whitehurst e as três da
/// resistividade) — a carbonatação precisa de quatro entradas e a inspeção
/// visual já é categórica, então ficam de fora.
class EscalaSegmentacaoBi {
  final String id;
  final String rotulo;
  final List<ClasseQualitativa> classes;
  final ClasseQualitativa? Function(double valor) classificar;
  const EscalaSegmentacaoBi(this.id, this.rotulo, this.classes, this.classificar);
}

final List<EscalaSegmentacaoBi> escalasSegmentacaoBi = [
  for (final c in classificadoresBi)
    if (c.distribuir == null && c.entradas.length == 1)
      for (var i = 0; i < c.dimensoes.length; i++)
        EscalaSegmentacaoBi(
          '${c.id}:$i',
          c.dimensoes.length == 1 ? c.rotulo : '${c.rotulo.split(' — ').first} — ${c.dimensoes[i].nome}',
          c.dimensoes[i].classes,
          (v) => c.dimensoes[i].classificar({c.entradas.keys.first: v}),
        ),
];

EscalaSegmentacaoBi? buscarEscalaSegmentacaoBi(String? id) => escalasSegmentacaoBi.where((e) => e.id == id).firstOrNull;

/// Opções de "Segmentar por" de uma barra segmentada.
const opcoesSegmentacaoBi = {
  'tipoElemento': 'Tipo de elemento',
  'local': 'Local',
  'estrutura': 'Estrutura',
  'categoria': 'Categoria (ex.: categoria da anomalia)',
  'classificacao': 'Classificação',
};

const _prefixoClassificacao = 'classificacao:';

bool segmentacaoPorClassificacao(String? segmentarPor) => segmentarPor?.startsWith(_prefixoClassificacao) ?? false;
String? escalaDaSegmentacao(String? segmentarPor) =>
    segmentacaoPorClassificacao(segmentarPor) ? segmentarPor!.substring(_prefixoClassificacao.length) : null;
String valorSegmentacaoClassificacao(String escalaId) => '$_prefixoClassificacao$escalaId';

/// Pedaços de uma barra segmentada: segmento -> grupo do eixo X -> altura.
class BarraSegmentadaBi {
  /// Na ordem de exibição (para classificação: da classe mais grave para a
  /// mais branda).
  final List<String> segmentos;
  final Map<String, Map<String, double>> valores;

  /// Cor fixa por segmento, quando o segmento tem uma (classes).
  final Map<String, Color> cores;

  /// Unidade da altura, quando ela deixa de ser a da variável.
  final String? unidade;

  const BarraSegmentadaBi(this.segmentos, this.valores, {this.cores = const {}, this.unidade});
}

/// Divide os pontos de uma série em segmentos.
///
///  - Por tipo, local, estrutura ou categoria: cada pedaço é o VALOR da
///    variável naquele recorte, com a agregação do campo — soma para o GUT
///    (então os pedaços somam o total do grupo), média para medições.
///  - Por classificação: cada pedaço é a QUANTIDADE DE ELEMENTOS naquela
///    classe. Empilhar médias de velocidade por classe não teria
///    significado; contar elementos tem.
BarraSegmentadaBi segmentarSerieBi({
  required List<BiDataPoint> pontos,
  required String agruparPor,
  required String segmentarPor,
  AgregacaoBi agregacao = AgregacaoBi.media,
}) {
  final escala = buscarEscalaSegmentacaoBi(escalaDaSegmentacao(segmentarPor));
  if (escala != null) return _porClassificacao(pontos, agruparPor, escala);

  String segmentoDe(BiDataPoint p) => switch (segmentarPor) {
        'categoria' => p.categoria ?? 'Sem categoria',
        _ => chaveAgrupamentoBi(p, segmentarPor),
      };

  final porSegmento = <String, List<BiDataPoint>>{};
  for (final p in pontos) {
    porSegmento.putIfAbsent(segmentoDe(p), () => []).add(p);
  }
  final valores = {
    for (final e in porSegmento.entries) e.key: agruparValoresBi(e.value, agruparPor, agregacao: agregacao),
  };
  return BarraSegmentadaBi(porSegmento.keys.toList()..sort(), valores);
}

BarraSegmentadaBi _porClassificacao(List<BiDataPoint> pontos, String agruparPor, EscalaSegmentacaoBi escala) {
  // Um valor por elemento (média dos seus pontos) antes de classificar: é o
  // elemento que se conta, não cada leitura.
  final porElemento = <String, List<BiDataPoint>>{};
  for (final p in pontos) {
    if (p.valor == null) continue;
    porElemento.putIfAbsent(p.elementoId, () => []).add(p);
  }

  final valores = <String, Map<String, double>>{};
  for (final pts in porElemento.values) {
    final media = pts.map((p) => p.valor!).reduce((a, b) => a + b) / pts.length;
    final classe = escala.classificar(media);
    if (classe == null) continue;
    final grupo = chaveAgrupamentoBi(pts.first, agruparPor);
    final linha = valores.putIfAbsent(classe.texto, () => {});
    linha[grupo] = (linha[grupo] ?? 0) + 1;
  }

  final presentes = escala.classes.where((c) => valores.containsKey(c.texto)).toList();
  return BarraSegmentadaBi(
    [for (final c in presentes) c.texto],
    valores,
    cores: {for (final c in presentes) c.texto: c.corTexto},
    unidade: 'elementos',
  );
}
