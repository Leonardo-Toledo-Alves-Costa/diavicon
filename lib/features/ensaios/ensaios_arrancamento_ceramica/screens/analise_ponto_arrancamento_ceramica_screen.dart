import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../models/ponto_arrancamento_ceramica_model.dart';
import '../repositories/arrancamento_ceramica_repository.dart';

class _RupturaPieData {
  final String label;
  final double value;
  final Color color;
  _RupturaPieData(this.label, this.value, this.color);
}

class AnalisePontoArrancamentoCeramicaScreen extends ConsumerStatefulWidget {
  final String pontoGeralId;
  final String pontoNome;
  final String elementoNome;
  final String local;

  const AnalisePontoArrancamentoCeramicaScreen({
    super.key,
    required this.pontoGeralId,
    required this.pontoNome,
    required this.elementoNome,
    required this.local,
  });

  @override
  ConsumerState<AnalisePontoArrancamentoCeramicaScreen> createState() => _AnalisePontoArrancamentoCeramicaScreenState();
}

class _AnalisePontoArrancamentoCeramicaScreenState extends ConsumerState<AnalisePontoArrancamentoCeramicaScreen> {
  bool _isLoading = true;
  PontoArrancamentoCeramicaModel? _modelo;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final repo = ref.read(arrancamentoCeramicaRepositoryProvider);
      _modelo = await repo.buscarPontoArrancamento(widget.pontoGeralId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _media => _modelo?.leituras.isEmpty ?? true ? 0.0 : _modelo!.mediaTensao;
  
  double get _maior => _modelo?.leituras.isEmpty ?? true 
      ? 0.0 : _modelo!.leituras.map((e) => e.tensaoCalculada).reduce(max);
  
  double get _menor {
    if (_modelo == null || _modelo!.leituras.isEmpty) return 0.0;
    final validas = _modelo!.leituras.where((e) => e.tensaoCalculada > 0).toList();
    if (validas.isEmpty) return 0.0;
    return validas.map((e) => e.tensaoCalculada).reduce(min);
  }

  double get _coefVar => _modelo?.coefVariacao ?? 0.0;

  // Cores personalizadas para as camadas de cerâmica
  Color _getCorRuptura(String sigla) {
    sigla = sigla.toUpperCase().trim();
    switch (sigla) {
      case 'S': return const Color(0xFF795548); // Marrom
      case 'E': return Colors.grey.shade600; // Cinza
      case 'AC': return Colors.orange; // Laranja
      case 'PC': return const Color(0xFFD84315); // Vermelho Telha
      case 'S/E': return const Color(0xFFA1887F); // Marrom Claro
      case 'E/AC': return const Color(0xFFFFB74D); // Laranja Claro
      case 'AC/PC': return const Color(0xFFFF8A65); // Salmão
      default: return Colors.primaries[sigla.hashCode % Colors.primaries.length];
    }
  }

  List<_RupturaPieData> _gerarDadosPizza() {
    final Map<String, double> somas = {
      'S': 0, 'E': 0, 'AC': 0, 'PC': 0, 'S/E': 0, 'E/AC': 0, 'AC/PC': 0,
    };
    int totalValidas = 0;

    if (_modelo != null) {
      for (var l in _modelo!.leituras) {
        if (l.rupturas.isNotEmpty) {
          totalValidas++;
          for (var r in l.rupturas) {
            final cat = CatalogoRupturasCeramica.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
            if (cat != null && somas.containsKey(cat.sigla)) {
              somas[cat.sigla] = somas[cat.sigla]! + r.porcentagem;
            }
          }
        }
      }
    }

    if (totalValidas == 0) return [];
    somas.updateAll((key, value) => value / totalValidas);
    
    return somas.entries.where((e) => e.value > 0).map((e) => _RupturaPieData(e.key, e.value, _getCorRuptura(e.key))).toList();
  }

  List<StackedColumnSeries<PontoLeituraCeramicaModel, String>> _gerarSeriesBarras() {
    if (_modelo == null || _modelo!.leituras.isEmpty) return [];

    final Set<String> rupturasPresentes = {};
    for (var l in _modelo!.leituras) {
      for (var r in l.rupturas) {
        if (r.porcentagem > 0) {
          final cat = CatalogoRupturasCeramica.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
          if (cat != null) rupturasPresentes.add(cat.sigla);
        }
      }
    }

    final List<StackedColumnSeries<PontoLeituraCeramicaModel, String>> series = [];
    
    for (var sigla in rupturasPresentes) {
      series.add(
        StackedColumnSeries<PontoLeituraCeramicaModel, String>(
          name: sigla,
          dataSource: _modelo!.leituras,
          xValueMapper: (datum, _) => datum.nome,
          yValueMapper: (datum, _) {
            double perc = 0.0;
            for (var r in datum.rupturas) {
              final cat = CatalogoRupturasCeramica.itens.where((c) => c.titulo == r.tipoRuptura).firstOrNull;
              if (cat != null && cat.sigla == sigla) perc += r.porcentagem;
            }
            if (perc == 0) return null; 
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
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final bool isHomogeneo = _coefVar <= 20; 
    final seriesBarras = _gerarSeriesBarras();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(systemNavigationBarColor: Colors.white),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: const CustomAppBar(
          title: 'Ensaio Cerâmica',
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${widget.pontoNome} - ${widget.elementoNome}', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                  ),
                ],
              ),
              Text(widget.local, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF888888))),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))]),
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

              if (seriesBarras.isNotEmpty)
                SizedBox(
                  height: 280, 
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap, iconHeight: 10, iconWidth: 10, textStyle: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade800)),
                    primaryXAxis: CategoryAxis(title: AxisTitle(text: 'Pontos de Ensaio', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)), majorGridLines: const MajorGridLines(width: 0), axisLine: const AxisLine(width: 1, color: Colors.grey)),
                    primaryYAxis: NumericAxis(title: AxisTitle(text: 'Tensão de Arrancamento (MPa)', textStyle: const TextStyle(fontSize: 10, color: Colors.grey)), axisLine: const AxisLine(width: 0), majorTickLines: const MajorTickLines(size: 0), majorGridLines: MajorGridLines(width: 1, color: Colors.grey.shade200, dashArray: const [5, 5])),
                    series: seriesBarras,
                  ),
                )
              else
                const Center(child: Text('Sem dados para o gráfico de barras')),
              
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))]),
                      child: Column(
                        children: [
                          Text('Coef.de variação', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('${_coefVar.toStringAsFixed(0)}%', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF3E3E3D))),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: isHomogeneo ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Text(isHomogeneo ? 'Homogêneo' : 'Heterogêneo', style: GoogleFonts.lato(color: isHomogeneo ? const Color(0xFF2E7D32) : Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ),
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