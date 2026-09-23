import 'dart:math';

import '../../../core/utils/monte_carlo.dart';
import '../../ensaios/ensaios_carbonatacao/utils/curva_despassivacao.dart';
import '../models/bi_data_point.dart';
import '../models/campos_bi_catalogo.dart';
import '../models/monte_carlo_bi_model.dart';
import '../models/serie_bi_model.dart';
import 'variavel_bi_avaliador.dart';

/// Estatística da população que originou uma série base.
class PopulacaoMC {
  final int n;
  final double media;
  final double desvio;
  const PopulacaoMC(this.n, this.media, this.desvio);
  double get coefVariacao => media == 0 ? 0 : desvio / media * 100;
}

class ResultadoSimulacaoMC {
  /// nome da série -> 1.000 amostras (NaN onde a expressão não deu número).
  final Map<String, List<double>> amostras;

  /// nome da série -> por que não pôde ser simulada.
  final Map<String, String> erros;

  /// Só séries base: a população real de onde saíram média e desvio.
  final Map<String, PopulacaoMC> populacoes;

  const ResultadoSimulacaoMC(this.amostras, this.erros, this.populacoes);
}

/// Referência de uma série base para a busca: força estatística nula para
/// campos agregados — a população do Monte Carlo são os valores de cada
/// ponto, não a média/desvio/CV já resumidos por ponto.
ReferenciaValorBi referenciaParaSimulacao(ReferenciaValorBi v) =>
    ReferenciaValorBi(fonte: v.fonte, campo: v.campo, variavelId: v.variavelId, variavelInline: v.variavelInline);

double _media(List<double> v) => v.reduce((a, b) => a + b) / v.length;

/// Desvio padrão AMOSTRAL (n − 1), o mesmo dos relatórios.
double _desvio(List<double> v) {
  if (v.length < 2) return 0;
  final m = _media(v);
  return sqrt(v.map((x) => pow(x - m, 2)).reduce((a, b) => a + b) / (v.length - 1));
}

/// Roda as séries de um card.
///
/// [porSerieId] traz os pontos buscados de cada série base. [chaveCard]
/// entra na semente: dois cards diferentes com a mesma série não
/// compartilham sorteio, mas o mesmo card mostra sempre o mesmo resultado.
ResultadoSimulacaoMC simularMonteCarlo(
  ConfigMonteCarloBi cfg,
  Map<String, List<BiDataPoint>> porSerieId, {
  required String chaveCard,
}) {
  final amostras = <String, List<double>>{};
  final erros = <String, String>{};
  final populacoes = <String, PopulacaoMC>{};

  // 1. Bases: média + z·σ da população do contexto.
  for (final s in cfg.series.where((s) => !s.derivada)) {
    final valores = (porSerieId[s.id] ?? const <BiDataPoint>[])
        .map((p) => p.valor)
        .whereType<double>()
        .where((v) => !v.isNaN && !v.isInfinite)
        .toList();
    if (valores.isEmpty) {
      erros[s.nome] = 'Sem dados no contexto do dashboard.';
      continue;
    }
    final pop = PopulacaoMC(valores.length, _media(valores), _desvio(valores));
    populacoes[s.nome] = pop;
    amostras[s.nome] = MonteCarlo.amostrarNormal(media: pop.media, desvio: pop.desvio, chave: '$chaveCard|${s.id}');
  }

  // 2. Derivadas, em ordem de dependência: uma derivada pode usar outra.
  final pendentes = cfg.series.where((s) => s.derivada).toList();
  var avancou = true;
  while (pendentes.isNotEmpty && avancou) {
    avancou = false;
    for (final s in [...pendentes]) {
      final usados = VariavelBiAvaliador.nomesUsados(s.expressao!);
      final falhou = usados.where(erros.containsKey).toList();
      if (falhou.isNotEmpty) {
        erros[s.nome] = 'Depende de "${falhou.first}", que não pôde ser simulada.';
        pendentes.remove(s);
        avancou = true;
        continue;
      }
      if (!usados.every(amostras.containsKey)) continue;

      final expr = VariavelBiAvaliador.compilar(s.expressao!);
      if (expr == null) {
        erros[s.nome] = 'Expressão inválida.';
      } else {
        amostras[s.nome] = List.generate(MonteCarlo.iteracoes, (i) {
          final vars = {for (final n in usados) n: amostras[n]![i]};
          return VariavelBiAvaliador.avaliarCompilada(expr, vars) ?? double.nan;
        });
      }
      pendentes.remove(s);
      avancou = true;
    }
  }
  // O que sobrou referencia série inexistente ou forma ciclo (A usa B, B usa A).
  for (final s in pendentes) {
    erros[s.nome] = 'Referência circular ou série inexistente na expressão.';
  }

  return ResultadoSimulacaoMC(amostras, erros, populacoes);
}

/// Resolve um operando: nome de série simulada ou número. Null se não
/// existir.
List<double>? operandoMC(String? operando, ResultadoSimulacaoMC r) {
  if (operando == null || operando.trim().isEmpty) return null;
  final numero = double.tryParse(operando.replaceAll(',', '.').trim());
  if (numero != null) return List.filled(MonteCarlo.iteracoes, numero);
  return r.amostras[operando.trim()];
}

// ── Despassivação ──────────────────────────────────────────────────────────

/// Aliases das entradas da análise de despassivação.
const entradasDespassivacaoMC = {
  'frente': ReferenciaValorBi(fonte: 'carbonatacao', campo: 'frente_leituras'),
  'cobP': ReferenciaValorBi(fonte: 'carbonatacao', campo: 'cob_arm_p'),
  'cobS': ReferenciaValorBi(fonte: 'carbonatacao', campo: 'cob_arm_s'),
  'idade': ReferenciaValorBi(fonte: 'dados_gerais', campo: 'idade'),
};

class ResultadoDespassivacaoMC {
  final CurvaDespassivacao? curva;
  final double idadeReferencia;
  final String? erro;
  const ResultadoDespassivacaoMC({this.curva, this.idadeReferencia = 0, this.erro});
}

/// Monta a curva a partir dos dados do contexto, com as mesmas entradas que
/// o relatório usa — frente pelas leituras individuais, cobrimento por ponto,
/// k = frente/√idade — e a mesma chave ([CurvaDespassivacao.chaveGeral]).
///
/// Diferença deliberada em relação ao relatório: se um dos cobrimentos não
/// foi medido, usa o outro. O relatório trata a média ausente como 0, que
/// "vence" como menor cobrimento e leva a 100% de falha por falta de dado.
ResultadoDespassivacaoMC despassivacaoMC(Map<String, List<BiDataPoint>> porAlias) {
  // Idade por elemento: num dashboard de projeto os elementos podem ser de
  // estruturas de idades diferentes, e k de cada leitura usa a sua.
  final idadePorElemento = <String, double>{
    for (final p in porAlias['idade'] ?? const <BiDataPoint>[])
      if (p.valor != null && p.valor! > 0) p.elementoId: p.valor!,
  };

  final ks = <double>[];
  for (final p in porAlias['frente'] ?? const <BiDataPoint>[]) {
    final idade = idadePorElemento[p.elementoId];
    if (p.valor == null || idade == null) continue;
    ks.add(p.valor! / sqrt(max(1.0, idade)));
  }
  if (ks.isEmpty) return const ResultadoDespassivacaoMC(erro: 'Sem leituras de frente de carbonatação (ou sem idade da estrutura).');

  List<double> cobertura(String alias) =>
      (porAlias[alias] ?? const <BiDataPoint>[]).map((p) => p.valor).whereType<double>().where((v) => v > 0).toList();
  final cobP = cobertura('cobP');
  final cobS = cobertura('cobS');
  if (cobP.isEmpty && cobS.isEmpty) {
    return const ResultadoDespassivacaoMC(erro: 'Sem cobrimento medido — não dá para estimar a despassivação.');
  }

  // Menor cobrimento médio (normalmente o da armadura secundária), com o
  // desvio do mesmo grupo — a regra dos relatórios.
  final double mediaCob;
  final double dpCob;
  if (cobS.isEmpty || (cobP.isNotEmpty && _media(cobP) < _media(cobS))) {
    mediaCob = _media(cobP);
    dpCob = _desvio(cobP);
  } else {
    mediaCob = _media(cobS);
    dpCob = _desvio(cobS);
  }

  final kMd = _media(ks);
  final kDp = _desvio(ks);
  final idadeRef = idadePorElemento.isEmpty ? 1.0 : _media(idadePorElemento.values.toList());

  final tempoTotal = kMd > 0 ? pow(mediaCob / kMd, 2).toDouble() : 999.0;
  final residual = max(0.0, tempoTotal - idadeRef);
  final tempoCalc = residual == 0 ? idadeRef : tempoTotal;

  return ResultadoDespassivacaoMC(
    idadeReferencia: idadeRef,
    curva: CurvaDespassivacao.calcular(
      kMedia: kMd,
      kDesvio: kDp,
      cobMedia: mediaCob,
      cobDesvio: dpCob,
      horizonte: CurvaDespassivacao.horizontePadrao(tempoCalc),
      chave: CurvaDespassivacao.chaveGeral,
    ),
  );
}

/// Rótulo legível de um operando (nome da série ou número).
String rotuloOperandoMC(String? operando) => operando == null || operando.isEmpty ? '?' : operando;

/// Unidade de uma série base, para os eixos e o resumo.
String? unidadeSerieMC(SerieMonteCarloBi s) {
  if (s.derivada || s.valor == null) return null;
  final v = s.valor!;
  if (v.ehVariavel) return v.variavelInline?['unidade']?.toString();
  return (v.fonte != null && v.campo != null) ? buscarCampoBi(v.fonte!, v.campo!)?.unidade : null;
}
