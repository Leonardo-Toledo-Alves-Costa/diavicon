import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/monte_carlo.dart';
import '../models/bi_data_point.dart';
import '../models/dashboard_card_model.dart';
import '../models/monte_carlo_bi_model.dart';
import '../utils/formato_bi.dart';
import '../utils/monte_carlo_bi.dart';
import '../utils/cores_bi.dart';

typedef _Faixa = ({double centro, double frequencia});

/// Card de simulação de Monte Carlo: distribuição, probabilidade de
/// ocorrência ou probabilidade de despassivação no tempo.
///
/// Stateful só para guardar o resultado: a simulação (1.000 amostras por
/// série, mais as derivadas) é refeita apenas quando os dados ou o card
/// mudam, não a cada rebuild do grid.
class BiMonteCarloCard extends StatefulWidget {
  const BiMonteCarloCard({super.key, required this.card, required this.series});

  final DashboardCardModel card;
  final Map<String, List<BiDataPoint>> series;

  @override
  State<BiMonteCarloCard> createState() => _BiMonteCarloCardState();
}

class _BiMonteCarloCardState extends State<BiMonteCarloCard> {
  ResultadoSimulacaoMC? _simulacao;
  ResultadoDespassivacaoMC? _despassivacao;

  @override
  void initState() {
    super.initState();
    _calcular();
  }

  @override
  void didUpdateWidget(covariant BiMonteCarloCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.series, widget.series) || !identical(old.card, widget.card)) _calcular();
  }

  void _calcular() {
    final cfg = widget.card.monteCarlo;
    if (cfg == null) return;
    if (cfg.analise == AnaliseMonteCarloBi.despassivacao) {
      _despassivacao = despassivacaoMC(widget.series);
    } else {
      _simulacao = simularMonteCarlo(cfg, widget.series, chaveCard: widget.card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.card.monteCarlo;
    if (cfg == null) return const SizedBox.shrink();
    return switch (cfg.analise) {
      AnaliseMonteCarloBi.distribuicao => _distribuicao(cfg),
      AnaliseMonteCarloBi.probabilidade => _probabilidade(cfg),
      AnaliseMonteCarloBi.despassivacao => _curvaDespassivacao(),
    };
  }

  // ── Distribuição ─────────────────────────────────────────────────────────

  Widget _distribuicao(ConfigMonteCarloBi cfg) {
    final sim = _simulacao!;
    final nome = cfg.serieExibida ?? (cfg.series.isEmpty ? null : cfg.series.last.nome);
    final amostra = nome == null ? null : sim.amostras[nome];
    if (amostra == null) return _vazio(sim.erros[nome] ?? 'Sem dados para simular');

    final resumo = MonteCarlo.resumo(amostra);
    final serie = cfg.series.where((s) => s.nome == nome).firstOrNull;
    final unidade = serie == null ? null : unidadeSerieMC(serie);
    final u = unidade == null ? '' : ' $unidade';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _histograma(MonteCarlo.histograma(amostra), Color(corBiNormalizada(serie?.cor ?? corPadraoBiInt)))),
        if (resumo != null)
          Text(
            'média ${formatarNumeroBi(resumo.media)}$u · σ ${formatarNumeroBi(resumo.desvio)}$u · '
            'CV ${formatarNumeroBi(resumo.coefVariacao)}% · P5–P95 ${formatarNumeroBi(resumo.p5)}–${formatarNumeroBi(resumo.p95)}$u',
            style: GoogleFonts.lato(fontSize: 10, color: AppColors.greyMediumDark),
          ),
        _rodapePopulacao(sim, nome!),
        _erros(sim),
      ],
    );
  }

  // ── Probabilidade de ocorrência ─────────────────────────────────────────

  Widget _probabilidade(ConfigMonteCarloBi cfg) {
    final sim = _simulacao!;
    final a = operandoMC(cfg.operandoA, sim);
    final b = operandoMC(cfg.operandoB, sim);
    if (a == null || b == null) {
      final faltando = a == null ? cfg.operandoA : cfg.operandoB;
      return _vazio(sim.erros[faltando] ?? 'Operando "${rotuloOperandoMC(faltando)}" sem dados');
    }

    final p = MonteCarlo.probabilidade(a, cfg.comparacao, b);
    final bConstante = double.tryParse((cfg.operandoB ?? '').replaceAll(',', '.').trim());

    // B fixo: histograma de A com a linha em B. B série: histograma de A − B
    // com a linha em 0 — é a diferença que decide a comparação.
    final List<double> base;
    final double marca;
    final String rotuloMarca;
    if (bConstante != null) {
      base = a;
      marca = bConstante;
      rotuloMarca = formatarNumeroBi(bConstante);
    } else {
      base = [for (var i = 0; i < a.length; i++) a[i] - b[i]];
      marca = 0;
      rotuloMarca = '${cfg.operandoA} = ${cfg.operandoB}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'P(${rotuloOperandoMC(cfg.operandoA)} ${cfg.comparacao.simbolo} ${rotuloOperandoMC(cfg.operandoB)}) = ',
              style: GoogleFonts.lato(fontSize: 13, color: AppColors.greyMediumDark),
            ),
            TextSpan(
              text: p.isNaN ? '—' : '${formatarNumeroBi(p * 100)}%',
              style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
            ),
          ]),
        ),
        if (bConstante == null)
          Text('Distribuição de ${cfg.operandoA} − ${cfg.operandoB}',
              style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
        Expanded(child: _histograma(MonteCarlo.histograma(base), AppColors.primary, marca: marca, rotuloMarca: rotuloMarca)),
        _erros(sim),
      ],
    );
  }

  // ── Despassivação no tempo ─────────────────────────────────────────────

  Widget _curvaDespassivacao() {
    final r = _despassivacao!;
    if (r.curva == null) return _vazio(r.erro ?? 'Sem dados de carbonatação');
    final curva = r.curva!;
    final pontos = [for (var i = 0; i < curva.tempos.length; i++) (t: curva.tempos[i], p: curva.probabilidades[i])];

    String tempoAte(double alvo) {
      final t = curva.tempoAte(alvo);
      return t == null ? '> ${formatarNumeroBi(curva.horizonte)}' : formatarNumeroBi(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hoje (${formatarNumeroBi(r.idadeReferencia)} anos): ${formatarNumeroBi(curva.probabilidadeEm(r.idadeReferencia))}%',
          style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textDark),
        ),
        Expanded(
          child: SfCartesianChart(
            margin: const EdgeInsets.fromLTRB(0, 4, 4, 0),
            tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x anos: point.y%'),
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Exposição (anos)', textStyle: GoogleFonts.lato(fontSize: 10)),
              labelStyle: GoogleFonts.lato(fontSize: 10),
              plotBands: [
                PlotBand(
                  start: r.idadeReferencia,
                  end: r.idadeReferencia,
                  borderWidth: 1.5,
                  borderColor: Colors.orange,
                  text: 'Idade',
                  textStyle: GoogleFonts.lato(fontSize: 9, color: Colors.orange),
                  verticalTextAlignment: TextAnchor.start,
                ),
              ],
            ),
            primaryYAxis: NumericAxis(
              minimum: 0,
              maximum: 100,
              title: AxisTitle(text: 'Probabilidade (%)', textStyle: GoogleFonts.lato(fontSize: 10)),
              labelStyle: GoogleFonts.lato(fontSize: 10),
            ),
            series: [
              AreaSeries<({double t, double p}), double>(
                dataSource: pontos,
                xValueMapper: (d, _) => d.t,
                yValueMapper: (d, _) => d.p,
                color: Colors.red.withValues(alpha: 0.18),
                borderColor: Colors.red,
                borderWidth: 2,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final alvo in const [20.0, 40.0, 60.0, 80.0])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
                child: Text('${alvo.toStringAsFixed(0)}%: ${tempoAte(alvo)} anos',
                    style: GoogleFonts.lato(fontSize: 10, color: const Color(0xFFB71C1C), fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ],
    );
  }

  // ── Peças ────────────────────────────────────────────────────────────────

  Widget _histograma(List<_Faixa> faixas, Color cor, {double? marca, String? rotuloMarca}) {
    return SfCartesianChart(
      margin: const EdgeInsets.fromLTRB(0, 4, 4, 0),
      tooltipBehavior: TooltipBehavior(enable: true, format: 'point.x: point.y%'),
      primaryXAxis: NumericAxis(
        labelStyle: GoogleFonts.lato(fontSize: 10),
        majorGridLines: const MajorGridLines(width: 0),
        plotBands: [
          if (marca != null)
            PlotBand(
              start: marca,
              end: marca,
              borderWidth: 1.5,
              borderColor: Colors.red,
              text: rotuloMarca,
              textStyle: GoogleFonts.lato(fontSize: 9, color: Colors.red),
              verticalTextAlignment: TextAnchor.start,
            ),
        ],
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Frequência (%)', textStyle: GoogleFonts.lato(fontSize: 10)),
        labelStyle: GoogleFonts.lato(fontSize: 10),
      ),
      series: [
        ColumnSeries<_Faixa, double>(
          dataSource: faixas,
          xValueMapper: (f, _) => f.centro,
          yValueMapper: (f, _) => f.frequencia,
          color: cor.withValues(alpha: 0.75),
          width: 1,
          spacing: 0.05,
        ),
      ],
    );
  }

  Widget _rodapePopulacao(ResultadoSimulacaoMC sim, String nome) {
    final pop = sim.populacoes[nome];
    if (pop == null) return const SizedBox.shrink();
    return Text(
      'Base: ${pop.n} ${pop.n == 1 ? 'valor' : 'valores'} no contexto'
      '${pop.n < 3 ? ' — poucos dados, a dispersão não é representativa' : ''}',
      style: GoogleFonts.lato(fontSize: 9, color: pop.n < 3 ? Colors.orange.shade800 : Colors.grey),
    );
  }

  Widget _erros(ResultadoSimulacaoMC sim) {
    if (sim.erros.isEmpty) return const SizedBox.shrink();
    return Text(
      sim.erros.entries.map((e) => '${e.key}: ${e.value}').join('  ·  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.lato(fontSize: 9, color: Colors.orange.shade800),
    );
  }

  Widget _vazio(String motivo) =>
      Center(child: Text(motivo, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)));
}
