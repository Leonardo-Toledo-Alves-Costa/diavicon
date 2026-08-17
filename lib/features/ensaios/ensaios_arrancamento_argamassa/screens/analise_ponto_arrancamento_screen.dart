import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/ponto_arrancamento_model.dart';
import '../repositories/arrancamento_repository.dart';

// Classe auxiliar para o gráfico de pizza
class _RupturaPieData {
  final String label;
  final double value;
  final Color color;
  _RupturaPieData(this.label, this.value, this.color);
}

class AnalisePontoArrancamentoScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String local;

  const AnalisePontoArrancamentoScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.local,
  });

  @override
  ConsumerState<AnalisePontoArrancamentoScreen> createState() => _AnalisePontoArrancamentoScreenState();
}

class _AnalisePontoArrancamentoScreenState extends ConsumerState<AnalisePontoArrancamentoScreen> {
  bool _isLoading = true;
  PontoArrancamentoModel? _modelo;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(arrancamentoRepositoryProvider);
      _modelo = await repo.buscarPontoArrancamento(widget.pontoGeralId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ESTATÍSTICAS ---
  double get _media {
    if (_modelo == null || _modelo!.leituras.isEmpty) return 0.0;
    return _modelo!.mediaTensao;
  }

  double get _maior {
    if (_modelo == null || _modelo!.leituras.isEmpty) return 0.0;
    return _modelo!.leituras.map((e) => e.tensaoCalculada).reduce(max);
  }

  double get _menor {
    if (_modelo == null || _modelo!.leituras.isEmpty) return 0.0;
    final validas = _modelo!.leituras.where((e) => e.tensaoCalculada > 0).toList();
    if (validas.isEmpty) return 0.0;
    return validas.map((e) => e.tensaoCalculada).reduce(min);
  }

  double get _coefVar => _modelo?.coefVariacao ?? 0.0;

  // --- CORES PADRONIZADAS PARA RUPTURAS ---
  Color _getCorRuptura(String sigla) {
    switch (sigla) {
      case 'S': return const Color(0xFF795548); // Marrom
      case 'S/A': return const Color(0xFFF57C00); // Laranja escuro
      case 'A': return const Color(0xFFFFB300); // Âmbar
      case 'A/C': return const Color(0xFFFFD54F); // Amarelo
      case 'C/P': return const Color(0xFF81C784); // Verde claro
      case 'P': return const Color(0xFF388E3C); // Verde escuro
      default: return Colors.grey;
    }
  }

  // Calcula a média das porcentagens para o gráfico de pizza
  List<_RupturaPieData> _gerarDadosPizza() {
    final Map<String, double> somas = {
      'S': 0, 'S/A': 0, 'A': 0, 'A/C': 0, 'C/P': 0, 'P': 0,
    };
    int totalValidas = 0;

    if (_modelo != null) {
      for (var l in _modelo!.leituras) {
        if (l.rupturas.isNotEmpty) {
          totalValidas++;
          for (var r in l.rupturas) {
            final cat = CatalogoRupturas.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
            if (cat != null && somas.containsKey(cat.sigla)) {
              somas[cat.sigla] = somas[cat.sigla]! + r.porcentagem;
            }
          }
        }
      }
    }

    if (totalValidas == 0) return [];
    
    somas.updateAll((key, value) => value / totalValidas);
    
    return somas.entries
        .where((e) => e.value > 0)
        .map((e) => _RupturaPieData(e.key, e.value, _getCorRuptura(e.key)))
        .toList();
  }

  // Gera as séries empilhadas proporcionalmente ao tipo de ruptura para o gráfico de barras
  List<StackedColumnSeries<PontoArrancamentoLeituraModel, String>> _gerarSeriesBarras() {
    if (_modelo == null || _modelo!.leituras.isEmpty) return [];

    // 1. Descobrir quais rupturas realmente ocorreram (para não poluir a legenda)
    final Set<String> rupturasPresentes = {};
    for (var l in _modelo!.leituras) {
      for (var r in l.rupturas) {
        if (r.porcentagem > 0) {
          final cat = CatalogoRupturas.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
          if (cat != null) rupturasPresentes.add(cat.sigla);
        }
      }
    }

    // 2. Criar uma série Stacked para cada ruptura que existe
    final List<StackedColumnSeries<PontoArrancamentoLeituraModel, String>> series = [];
    
    for (var sigla in rupturasPresentes) {
      series.add(
        StackedColumnSeries<PontoArrancamentoLeituraModel, String>(
          name: sigla,
          dataSource: _modelo!.leituras,
          xValueMapper: (datum, _) => datum.nome,
          yValueMapper: (datum, _) {
            // Busca a porcentagem correspondente a essa série na leitura atual
            double perc = 0.0;
            for (var r in datum.rupturas) {
              final cat = CatalogoRupturas.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
              if (cat != null && cat.sigla == sigla) {
                perc += r.porcentagem;
              }
            }
            if (perc == 0) return null; // null evita renderizar pedaços zerados
            
            // O valor Y é proporcional à porcentagem da ruptura em relação à tensão total
            return datum.tensaoCalculada * (perc / 100.0);
          },
          color: _getCorRuptura(sigla),
        )
      );
    }

    return series;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white, 
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final bool isHomogeneo = _coefVar <= 20; 
    final dadosPizza = _gerarDadosPizza();
    final seriesBarras = _gerarSeriesBarras();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(systemNavigationBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: const CustomAppBar(
          title: 'Ensaio',
          showBackButton: true,
          showMenuButton: false,
          titleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70)),
              Text('Análise do Ensaio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- CABEÇALHO ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.pontoNome} - ${widget.elementoNome}',
                      style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D)),
                    ),
                  ),
                  const Icon(Icons.edit_square, color: Color(0xFF3E3E3D)),
                ],
              ),
              Text(
                widget.local,
                style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888)),
              ),
              const SizedBox(height: 24),

              // --- CARD RESUMO DA TENSÃO ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tensão de Ruptura', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 6),
                          Text('Maior: ${_maior.toStringAsFixed(2)} MPa\nMenor: ${_menor.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey, height: 1.4)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Média', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                        Text('${_media.toStringAsFixed(2)} MPa', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- GRÁFICO DE BARRAS EMPILHADO (Syncfusion) ---
              if (seriesBarras.isNotEmpty)
                SizedBox(
                  height: 280, // Aumentado ligeiramente para acomodar a legenda embaixo
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                      overflowMode: LegendItemOverflowMode.wrap,
                      iconHeight: 10,
                      iconWidth: 10,
                      textStyle: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade800),
                    ),
                    primaryXAxis: CategoryAxis(
                      title: AxisTitle(text: 'Pontos de Ensaio', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                      majorGridLines: const MajorGridLines(width: 0),
                      axisLine: const AxisLine(width: 1, color: Colors.grey),
                    ),
                    primaryYAxis: NumericAxis(
                      title: AxisTitle(text: 'Tensão de Arrancamento (MPa)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)),
                      axisLine: const AxisLine(width: 0),
                      majorTickLines: const MajorTickLines(size: 0),
                      majorGridLines: MajorGridLines(width: 1, color: Colors.grey.shade200, dashArray: const [5, 5]),
                    ),
                    series: seriesBarras,
                  ),
                )
              else
                const Center(child: Text('Sem dados para o gráfico de barras')),
              
              const SizedBox(height: 32),

              // --- INFERIOR: COEF. DE VARIAÇÃO & GRÁFICO DE PIZZA ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Card Coeficiente de Variação
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          Text('Coef.de variação', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('${_coefVar.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isHomogeneo ? 'Homogêneo' : 'Heterogêneo',
                              style: GoogleFonts.lato(color: isHomogeneo ? const Color(0xFF2E7D32) : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}