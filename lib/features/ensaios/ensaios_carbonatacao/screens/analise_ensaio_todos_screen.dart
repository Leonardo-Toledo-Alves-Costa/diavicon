import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_ensaio_todos_model.dart';
import '../models/carbonatacao_math.dart'; // Utilitário criado no Passo 2
import '../providers/analise_ensaio_todos_provider.dart';

class ChartData {
  final double x;
  final double y;
  ChartData(this.x, this.y);
}

class BoxPlotData {
  final String x;
  final List<double> y;
  BoxPlotData(this.x, this.y);
}

class AnaliseEnsaioScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String estruturaId;
  final String tipoEnsaioNome;
  final String projetoNome;
  final String estruturaNome;

  const AnaliseEnsaioScreen({
    super.key,
    required this.projetoId,
    required this.estruturaId,
    required this.tipoEnsaioNome,
    required this.projetoNome,
    required this.estruturaNome,
  });

  @override
  ConsumerState<AnaliseEnsaioScreen> createState() =>
      _AnaliseEnsaioScreenState();
}

class _AnaliseEnsaioScreenState extends ConsumerState<AnaliseEnsaioScreen> {
  int _abaSelecionada = 0; // 0: Análise, 1: Tabelas, 2: Estatísticas
  int _subAbaEstatistica = 0; // 0: Elementos, 1: Locais

  final String _searchQuery = '';
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';

  late TrackballBehavior _trackballfrente;
  late TrackballBehavior _trackballprob;

  // ==========================================
  // CÁLCULOS MATEMÁTICOS & ESTATÍSTICOS
  // ==========================================
  Map<String, dynamic> _calcularIndicadoresGlobais(
    List<AnalisePontoEnsaioModel> pontos,
  ) {
    if (pontos.isEmpty) return {};

    List<double> todasFrentes = [];
    List<double> todosCobsSec = [];
    List<double> todosCobsPrin = [];
    double idade = pontos.first.idade;

    for (var p in pontos) {
      todasFrentes.addAll(p.frentes);
      todosCobsPrin.addAll(p.cobrimentosPrin);
      todosCobsSec.addAll(p.cobrimentosSec);
    }

    // Médias e Desvios
    double mediaFt = CarbonatacaoMath.mean(todasFrentes);
    double dpFt = CarbonatacaoMath.stdDev(todasFrentes);
    double cvFt = (mediaFt > 0) ? (dpFt / mediaFt) * 100 : 0;

    double mediaCobPrin = CarbonatacaoMath.mean(todosCobsPrin);
    double dpCobPrin = CarbonatacaoMath.stdDev(todosCobsPrin);
    double cvCobPrin = (mediaCobPrin > 0)
        ? (dpCobPrin / mediaCobPrin) * 100
        : 0;

    double mediaCobSec = CarbonatacaoMath.mean(todosCobsSec);
    double dpCobSec = CarbonatacaoMath.stdDev(todosCobsSec);
    double cvCobSec = (mediaCobSec > 0) ? (dpCobSec / mediaCobSec) * 100 : 0;

    double mediaCob = min(mediaCobSec, mediaCobPrin);
    double dpCob = (mediaCobSec <= mediaCobPrin) ? dpCobSec : dpCobPrin;
    double cvCob = (mediaCobSec <= mediaCobPrin) ? cvCobSec : cvCobPrin;

    // Indicadores do Gráfico 01
    double coefCarb = mediaFt / sqrt(idade);
    double tempoCarbonatar = coefCarb > 0
        ? pow(mediaCob / coefCarb, 2).toDouble()
        : 999.0;
    double deltaCarb = tempoCarbonatar - idade;

    String condicao;
    if (deltaCarb <= 0)
      condicao = "Despassivado";
    else if (deltaCarb < 5)
      condicao = "Risco Alto";
    else if (deltaCarb < 15)
      condicao = "Risco Moderado";
    else if (deltaCarb < 30)
      condicao = "Risco Baixo";
    else
      condicao = "Risco Irrelevante";

    Color corCondicao;
    if (deltaCarb <= 0)
      corCondicao = Color(0xFFFF4C4C); // "Despassivado";
    else if (deltaCarb < 5)
      corCondicao = Color(0xFFFF8C00);
    else if (deltaCarb < 15)
      corCondicao = Color(0xFFFFB74D);
    else if (deltaCarb < 30)
      corCondicao = Color(0xFFAED581);
    else
      corCondicao = Color(0xFF81C784);

    double tempoCalc = (deltaCarb <= 0) ? idade : tempoCarbonatar;
    double tempoAnaliseG1 = max(idade * 2, tempoCarbonatar * 2);

    List<ChartData> curvaAvanco = [];
    double maxFrenteG1 = 0;
    for (double t = 0; t <= tempoAnaliseG1; t += (tempoAnaliseG1 / 100)) {
      double f = sqrt(t) * coefCarb;
      curvaAvanco.add(ChartData(t, f));
      if (f > maxFrenteG1) maxFrenteG1 = f;
    }

    // Condicional para o eixo Y do Gráfico 01
    double maxYG1 = max(maxFrenteG1, mediaCob) * 1.2;

    // Simulação de Monte Carlo (Gráfico 02)
    List<double> arrayK = todasFrentes.map((f) => f / sqrt(idade)).toList();
    double kMd = CarbonatacaoMath.mean(arrayK);
    double kDp = CarbonatacaoMath.stdDev(arrayK);

    double tempoAnalisePb = tempoCalc * (tempoCalc < 10 ? 3 : 2);
    int nSim = 1000;

    List<double> kSim = CarbonatacaoMath.randomNormal(kMd, kDp, nSim);
    List<double> cobSim = CarbonatacaoMath.randomNormal(mediaCob, dpCob, nSim);

    List<ChartData> curvaMonteCarlo = [];

    for (double t = 0; t <= tempoAnalisePb; t += (tempoAnalisePb / 100)) {
      if (t == 0) {
        curvaMonteCarlo.add(ChartData(0, 0));
        continue;
      }
      int falhas = 0;
      for (int i = 0; i < nSim; i++) {
        double x = kSim[i] * sqrt(t);
        if (x > cobSim[i]) falhas++;
      }
      curvaMonteCarlo.add(ChartData(t, (falhas / nSim) * 100));
    }

    // Função para achar ano alvo na curva de probabilidade
    String buscarTempoProb(double probAlvo) {
      for (var p in curvaMonteCarlo) {
        if (p.y >= probAlvo) return '${p.x.toStringAsFixed(1)} anos';
      }
      return '> ${tempoAnalisePb.toStringAsFixed(0)} anos';
    }

    return {
      'idade': idade,
      'mediaCob': mediaCob,
      'dpCob': dpCob,
      'cvCob': cvCob,
      'mediaCobPrin': mediaCobPrin,
      'dpCobPrin': dpCobPrin,
      'cvCobPrin': cvCobPrin,
      'mediaCobSec': mediaCobSec,
      'dpCobSec': dpCobSec,
      'cvCobSec': cvCobSec,
      'mediaFt': mediaFt,
      'dpFt': dpFt,
      'cvFt': cvFt,
      'coefCarb': coefCarb,
      'condicao': condicao,
      'cor_condicao': corCondicao,
      'tempoDesp': deltaCarb,
      'tempoateDesp': tempoCarbonatar,
      'tempoAnaliseG1': tempoAnaliseG1,
      'maxYG1': maxYG1,
      'curvaAvanco': curvaAvanco,
      'tempoAnalisePb': tempoAnalisePb,
      'curvaMonteCarlo': curvaMonteCarlo,
      't20': buscarTempoProb(20),
      't40': buscarTempoProb(40),
      't60': buscarTempoProb(60),
      't80': buscarTempoProb(80),
    };
  }

  @override
  void initState() {
    super.initState();
    _trackballfrente = _criarTrackball();
    _trackballprob = _criarTrackball();
  }

  TrackballBehavior _criarTrackball() {
    return TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,

      lineType: TrackballLineType.vertical,
      lineWidth: 1.5,
      lineColor: const Color(0xCCFFC107), // Amarelo DIAVICON

      tooltipDisplayMode:
          TrackballDisplayMode.groupAllPoints, //groupAllPoints floatAllPoints
      tooltipAlignment: ChartAlignment.far,
      markerSettings: const TrackballMarkerSettings(
        markerVisibility: TrackballVisibilityMode.visible,
        width: 6,
        height: 6,
        color: Color(0xCCFFC107),
        borderColor: Colors.white,
        borderWidth: 2,
      ),

      tooltipSettings: const InteractiveTooltip(
        enable: true,
        color: Color(0x33FFC107),
        textStyle: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        borderRadius: 10,
        borderWidth: 1,
        borderColor: Color(0xCCFFC107),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(
      analiseEnsaioProvider((
        projetoId: widget.projetoId,
        estruturaId: widget.estruturaId,
        tipoEnsaioNome: widget.tipoEnsaioNome,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          DiaviconMenuItem(
            icon: Icons.book_outlined,
            label: 'Informações',
            onTap: () => Navigator.pop(context),
          ),
          Opacity(
            opacity: 0.4,
            child: DiaviconMenuItem(
              icon: Icons.show_chart_rounded,
              label: 'Análises',
              onTap: () {},
            ),
          ),
          DiaviconMenuItem(
            icon: Icons.assessment_outlined,
            label: 'Relatórios',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
      appBar: const CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Projeto',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Análise',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Text('Erro: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (todosPontos) {
          if (todosPontos.isEmpty)
            return const Center(
              child: Text(
                'Nenhum ponto registrado para análise.',
                style: TextStyle(color: Colors.grey),
              ),
            );

          // Lista de locais para o Dropdown
          final todosLocais = [
            'Locais',
            ...todosPontos.map((p) => p.local).toSet(),
          ];

          final todosTiposElemento = [
            'Elementos',
            ...todosPontos.map((p) => p.tipoElemento).toSet().toList()..sort(),
          ];
          // Aplicando Filtros UI

          final pontosFiltro = todosPontos.where((p) {
            //final matchBusca = _searchQuery.isEmpty || p.local.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchDrop =
                _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo =
                _filtroTipoElemento == 'Elementos' ||
                p.tipoElemento == _filtroTipoElemento;
            return matchDrop && matchTipo;
          }).toList();

          final calc = _calcularIndicadoresGlobais(pontosFiltro);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Títulos e Filtros
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tipoEnsaioNome,
                      style: GoogleFonts.lato(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3E3E3D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.projetoNome,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: const Color(0xFF686868),
                      ),
                    ),
                    Text(
                      widget.estruturaNome,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: const Color(0xFF686868),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        //Expanded(flex: 2, child: CompactSearchBar(hintText: 'Local', onChanged: (val) => setState(() => _searchQuery = val))),
                        //const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFD9D9D9),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _filtroLocal,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: const Color(0xFF3E3E3D),
                                ),
                                items: todosLocais
                                    .map(
                                      (String value) =>
                                          DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _filtroLocal = val);
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          flex: 1,
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFD9D9D9),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _filtroTipoElemento,
                                style: GoogleFonts.lato(
                                  fontSize: 13,
                                  color: const Color(0xFF3E3E3D),
                                ),
                                items: todosTiposElemento
                                    .map(
                                      (String value) =>
                                          DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _filtroTipoElemento = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Abas
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(0, 'Análise'),
                      _buildTabButton(1, 'Tabelas'),
                      _buildTabButton(2, 'Estatísticas'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Conteúdo Dinâmico
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _abaSelecionada == 0
                      ? _buildAbaAnalise(calc)
                      : _abaSelecionada == 1
                      ? _buildAbaTabelas(calc)
                      : _buildAbaEstatistica(pontosFiltro),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton(int index, String titulo) {
    final selecionado = _abaSelecionada == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaSelecionada = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selecionado ? const Color(0xFFFFA726) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            titulo,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: selecionado ? Colors.white : const Color(0xFF686868),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ABA 1: ANÁLISE (GRÁFICOS E CARDS)
  // ==========================================
  Widget _buildAbaAnalise(Map<String, dynamic> calc) {
    if (calc.isEmpty) return const SizedBox();

    String qualidadeCv = calc['cvFt'] < 15
        ? 'Homogêneo'
        : calc['cvFt'] < 30
        ? 'Moderado'
        : 'Heterogêneo';
    Color corCv = calc['cvFt'] < 15
        ? Colors.green
        : calc['cvFt'] < 30
        ? Colors.orange
        : Colors.red;

    return Column(
      children: [
        // GRÁFICO 1: AVANÇO DA FRENTE
        Container(
          height: 320,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: SfCartesianChart(
            trackballBehavior: _trackballfrente,
            //trackballBehavior: _trackball,
            title: const ChartTitle(
              text: 'Avanço da frente de carbonatação ',
              textStyle: TextStyle(fontSize: 11),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
              overflowMode: LegendItemOverflowMode.wrap,
              orientation: LegendItemOrientation.vertical,
              textStyle: TextStyle(fontSize: 10),
            ),
            primaryXAxis: NumericAxis(
              title: const AxisTitle(
                text: 'Exposição (anos)',
                textStyle: TextStyle(fontSize: 10),
              ),
              minimum: 0,
              maximum: calc['tempoAnaliseG1'],
              interval: calc['tempoAnaliseG1'] < 40
                  ? 5
                  : calc['tempoAnaliseG1'] < 70
                  ? 10
                  : 20,
            ),
            primaryYAxis: NumericAxis(
              title: const AxisTitle(
                text: 'Profundidade (mm)',
                textStyle: TextStyle(fontSize: 10),
              ),
              minimum: 0,
              maximum: calc['maxYG1'],
              interval: calc['maxYG1'] < 40
                  ? 5
                  : calc['maxYG1'] < 70
                  ? 10
                  : 20,
            ),
            series: <CartesianSeries>[
              AreaSeries<ChartData, double>(
                dataSource: [
                  ChartData(0, calc['mediaCob']),
                  ChartData(calc['tempoAnaliseG1'], calc['mediaCob']),
                ],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: const Color(0x66C896FF),
                borderColor: const Color(0xFFC896FF),
                borderWidth: 2,
                name: 'Cobrimento (mm)',
              ),
              AreaSeries<ChartData, double>(
                dataSource: calc['curvaAvanco'],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.grey.shade600.withValues(alpha: 0.2),
                borderColor: Colors.grey.shade600,
                borderWidth: 2,
                name: 'Frente de Carbonatação (mm)',
              ),
              LineSeries<ChartData, double>(
                dataSource: [
                  ChartData(calc['idade'], 0),
                  ChartData(calc['idade'], calc['maxYG1']),
                ],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.orange,
                width: 2,
                dashArray: const <double>[6, 4],
                name: 'Idade',
              ),
              LineSeries<ChartData, double>(
                dataSource: [
                  ChartData(calc['tempoateDesp'], 0),
                  ChartData(calc['tempoateDesp'], calc['maxYG1']),
                ],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.red,
                width: 2,
                dashArray: const <double>[6, 4],
                name: 'Falha',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // CARDS INFORMATIVOS
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Coef. de Carbonatação',
                '${calc['coefCarb'].toStringAsFixed(2)} mm/ano²',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                'Coef. de variação',
                '${calc['cvFt'].toStringAsFixed(1)}%',
                badge: qualidadeCv,
                badgeColor: corCv,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // CARD DE ALERTA
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                // Este Expanded já estava correto
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tempo para despassivação',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (calc['cor_condicao'] as Color).withOpacity(
                          0.15,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        calc['condicao'],
                        style: TextStyle(
                          color: calc['cor_condicao'] as Color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 👇 A CORREÇÃO ENTRA AQUI: Usar Flexible + FittedBox
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    calc['condicao'] == "Despassivado"
                        ? 'Já ocorreu'
                        : '${calc['tempoDesp'].toStringAsFixed(0)} anos',
                    style: GoogleFonts.lato(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3E3E3D),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // GRÁFICO 2: PROBABILIDADE
        Container(
          height: 280,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: SfCartesianChart(
            trackballBehavior: _trackballprob,
            title: const ChartTitle(
              text: 'Estimativa da Probabilidade de Despassivação',
              textStyle: TextStyle(fontSize: 11),
            ),
            legend: const Legend(isVisible: true, position: LegendPosition.top),
            primaryXAxis: NumericAxis(
              title: const AxisTitle(
                text: 'Exposição (anos)',
                textStyle: TextStyle(fontSize: 10),
              ),
              minimum: 0,
              maximum: calc['tempoAnalisePb'],
              interval: calc['tempoAnalisePb'] < 40
                  ? 5
                  : calc['tempoAnalisePb'] < 70
                  ? 10
                  : 20,
            ),
            primaryYAxis: const NumericAxis(
              title: AxisTitle(
                text: 'Probabilidade de falha (%)',
                textStyle: TextStyle(fontSize: 10),
              ),
              minimum: 0,
              maximum: 100,
              interval: 10,
            ),
            series: <CartesianSeries>[
              AreaSeries<ChartData, double>(
                dataSource: calc['curvaMonteCarlo'],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.grey.shade300,
                borderColor: Colors.grey.shade600,
                borderWidth: 3,
                name: 'Probabilidade de falha (%)',
              ),
              LineSeries<ChartData, double>(
                dataSource: [
                  ChartData(calc['idade'], 0),
                  ChartData(calc['idade'], 100),
                ],
                xValueMapper: (d, _) => d.x,
                yValueMapper: (d, _) => d.y,
                color: Colors.orange,
                width: 2,
                dashArray: const <double>[6, 4],
                name: 'Idade',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String label,
    String valor, {
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: GoogleFonts.lato(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF3E3E3D),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor?.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // ABA 2: TABELAS
  // ==========================================
  Widget _buildAbaTabelas(Map<String, dynamic> calc) {
    if (calc.isEmpty) return const SizedBox();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                'Exposição',
                '${calc['idade'].toStringAsFixed(0)} anos',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoCard('Ambiente', 'Urbano'),
            ), // Fixo temporário para UI
            const SizedBox(width: 8),
            Expanded(
              child: _buildInfoCard('CAA', 'III'),
            ), // Fixo temporário para UI
          ],
        ),
        const SizedBox(height: 24),

        _buildTabela(
          tituloMain: 'Armaduras Avaliadas',
          headers: ['Armadura', 'Média (mm)', 'Desv. pad.', 'Coef. var. (%)'],
          linhas: [
            [
              'Principal',
              calc['mediaCobPrin'].toStringAsFixed(1),
              calc['dpCobPrin'].toStringAsFixed(1),
              calc['cvCobPrin'].toStringAsFixed(1),
            ],
            [
              'Secundária',
              calc['mediaCobSec'].toStringAsFixed(1),
              calc['dpCobSec'].toStringAsFixed(1),
              calc['cvCobSec'].toStringAsFixed(1),
            ],
          ],
          corHeader: const Color(0xFFFFA726),
        ),
        const SizedBox(height: 24),

        _buildTabela(
          tituloMain: 'Frente de Carbonatação',
          headers: ['', 'Média (mm)', 'Desv. pad.', 'Coef. var (%)'],
          linhas: [
            [
              'Resultados',
              calc['mediaFt'].toStringAsFixed(1),
              calc['dpFt'].toStringAsFixed(1),
              calc['cvFt'].toStringAsFixed(1),
            ],
            [
              'Coef. Carb. k (mm.ano²)',
              calc['coefCarb'].toStringAsFixed(2),
              '-',
              '-',
            ],
          ],
          corHeader: const Color(0xFFFFA726),
        ),
        const SizedBox(height: 24),

        _buildTabela(
          tituloMain: 'Probabilidade de despassivação ao longo do tempo',
          headers: [
            '',
            'Baixo (20%)',
            'Médio (40%)',
            'Alto (60%)',
            'Muito Alto (80%)',
          ],
          linhas: [
            ['Tempo', calc['t20'], calc['t40'], calc['t60'], calc['t80']],
          ],
          corHeader: const Color(0xFFFFA726),
          columnWidths: const {
            0: FixedColumnWidth(50),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
            3: FlexColumnWidth(),
            4: FlexColumnWidth(),
          },
        ),
      ],
    );
  }

  Widget _buildTabela({
    required String tituloMain,
    required List<String> headers,
    required List<List<String>> linhas,
    required Color corHeader,
    Map<int, TableColumnWidth>? columnWidths,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: corHeader,
            child: Text(
              tituloMain,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Table(
            border: TableBorder.symmetric(
              inside: BorderSide(color: Colors.grey.shade300),
            ),
            columnWidths:
                columnWidths ??
                {
                  for (int i = 0; i < headers.length; i++)
                    i: const FlexColumnWidth(),
                },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: headers
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          h,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

              ...linhas.map(
                (linha) => TableRow(
                  children: linha
                      .map(
                        (celula) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            celula,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ABA 3: ESTATÍSTICA (BOXPLOT)
  // ==========================================
  Widget _buildAbaEstatistica(List<AnalisePontoEnsaioModel> pontos) {
    Map<String, List<double>> mapaCobrimentoPrin = {};
    Map<String, List<double>> mapaCobrimentoSec = {};
    Map<String, List<double>> mapaFrente = {};

    // Agrupa dinamicamente pelo Tipo (Elementos) ou pelo Local
    for (var p in pontos) {
      String chave = _subAbaEstatistica == 0 ? p.tipoElemento : p.local;
      if (!mapaCobrimentoSec.containsKey(chave)) {
        mapaCobrimentoPrin[chave] = [];
        mapaCobrimentoSec[chave] = [];
        mapaFrente[chave] = [];
      }
      mapaCobrimentoPrin[chave]!.addAll(p.cobrimentosPrin);
      mapaCobrimentoSec[chave]!.addAll(p.cobrimentosSec);
      mapaFrente[chave]!.addAll(p.frentes);
    }

    List<BoxPlotData> dadosCobrimento = mapaCobrimentoSec.entries
        .map((e) => BoxPlotData(e.key, e.value))
        .toList();
    List<BoxPlotData> dadosFrente = mapaFrente.entries
        .map((e) => BoxPlotData(e.key, e.value))
        .toList();

    return Column(
      children: [
        Row(
          children: [
            _buildSubTabButton('Elementos', 0),
            const SizedBox(width: 12),
            _buildSubTabButton('Locais', 1),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          height: 400,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: SfCartesianChart(
            title: const ChartTitle(
              text: 'Boxplot dos resultados obtidos',
              textStyle: TextStyle(fontSize: 12),
            ),
            legend: const Legend(
              isVisible: true,
              position: LegendPosition.bottom,
            ),
            primaryXAxis: const CategoryAxis(),
            primaryYAxis: const NumericAxis(
              title: AxisTitle(
                text: 'Profundidade (mm)',
                textStyle: TextStyle(fontSize: 10),
              ),
            ),
            series: <CartesianSeries>[
              BoxAndWhiskerSeries<BoxPlotData, String>(
                dataSource: dadosCobrimento,
                xValueMapper: (BoxPlotData data, _) => data.x,
                yValueMapper: (BoxPlotData data, _) => data.y,
                name: 'Cobrimento',
                color: const Color(0x99FF69B4),
                boxPlotMode: BoxPlotMode.exclusive,
                showMean: true,
              ),
              BoxAndWhiskerSeries<BoxPlotData, String>(
                dataSource: dadosFrente,
                xValueMapper: (BoxPlotData data, _) => data.x,
                yValueMapper: (BoxPlotData data, _) => data.y,
                name: 'Carbonatação',
                color: const Color(0xB3787878),
                boxPlotMode: BoxPlotMode.exclusive,
                showMean: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(String label, int index) {
    final sel = _subAbaEstatistica == index;
    return InkWell(
      onTap: () => setState(() => _subAbaEstatistica = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFA726) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? Colors.transparent : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
