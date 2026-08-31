import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_appbar.dart';
import '../../../../core/widgets/diavicon_menu_item.dart';
import '../../../../core/widgets/menu_drawer_app_bar.dart';
import '../models/analise_potencial_global_model.dart';
import '../providers/analise_todos_potencial_provider.dart';

class AnaliseTodosPotencialScreen extends ConsumerStatefulWidget {
  final String projetoId;
  final String projetoNome;
  final String estruturaId;
  final String estruturaNome;
  final String tipoEnsaioId;
  final String tipoEnsaioNome;

  const AnaliseTodosPotencialScreen({
    super.key,
    required this.projetoId,
    required this.projetoNome,
    required this.estruturaId,
    required this.estruturaNome,
    required this.tipoEnsaioId,
    required this.tipoEnsaioNome,
  });

  @override
  ConsumerState<AnaliseTodosPotencialScreen> createState() => _AnaliseTodosPotencialScreenState();
}

class _AnaliseTodosPotencialScreenState extends ConsumerState<AnaliseTodosPotencialScreen> {
  String _filtroLocal = 'Locais';
  String _filtroTipoElemento = 'Elementos';

  // Paleta de cores para diferenciar os Locais no gráfico
  final List<Color> _paletaLocais = [
    const Color(0xFF5C6BC0), // Indigo/Azul (Garagem)
    const Color(0xFFEF5350), // Vermelho claro (Cobertura)
    const Color(0xFF66BB6A), // Verde
    const Color(0xFFFFA726), // Laranja
    const Color(0xFFAB47BC), // Roxo
  ];

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(analiseTodosPotencialProvider((
      projetoId: widget.projetoId,
      estruturaId: widget.estruturaId,
    )));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: MenuDrawerAppBar(
        title: 'Menu do\nEnsaio',
        items: [
          DiaviconMenuItem(icon: Icons.book_outlined, label: 'Informações', onTap: () => Navigator.pop(context)),
          Opacity(opacity: 0.4, child: DiaviconMenuItem(icon: Icons.show_chart_rounded, label: 'Análises', onTap: () {})),
          DiaviconMenuItem(icon: Icons.assessment_outlined, label: 'Relatórios', onTap: () => Navigator.pop(context)),
        ],
      ),
      appBar: CustomAppBar(
        title: 'Ensaio',
        showBackButton: true,
        showMenuButton: false,
        titleWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Projeto', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            const Text('Análise Global', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Erro: $err', style: const TextStyle(color: Colors.red))),
        data: (todosPontos) {
          if (todosPontos.isEmpty) {
            return const Center(child: Text('Nenhum ponto registrado.', style: TextStyle(color: Colors.grey)));
          }

          // Montar as listas de dropdown
          final todosLocais = ['Locais', ...todosPontos.map((p) => p.local).toSet()];
          final todosTipos = ['Elementos', ...todosPontos.map((p) => p.tipoElemento).toSet().toList()..sort()];

          // Aplicar Filtros
          final pontosFiltro = todosPontos.where((p) {
            final matchDrop = _filtroLocal == 'Locais' || p.local == _filtroLocal;
            final matchTipo = _filtroTipoElemento == 'Elementos' || p.tipoElemento == _filtroTipoElemento;
            return matchDrop && matchTipo;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCabecalho(todosLocais, todosTipos),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _buildAbaGraficos(pontosFiltro),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // CABEÇALHO (Títulos e Filtros)
  // ==========================================
  Widget _buildCabecalho(List<String> locais, List<String> elementos) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Potencial de corrosão', style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF3E3E3D))),
          const SizedBox(height: 2),
          Text(widget.projetoNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          Text(widget.estruturaNome, style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF686868))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildFiltroDropdown(_filtroLocal, locais, (val) => setState(() => _filtroLocal = val!))),
              const SizedBox(width: 10),
              Expanded(child: _buildFiltroDropdown(_filtroTipoElemento, elementos, (val) => setState(() => _filtroTipoElemento = val!))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroDropdown(String value, List<String> items, void Function(String?) onChanged) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          style: GoogleFonts.lato(fontSize: 13, color: const Color(0xFF3E3E3D)),
          items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==========================================
  // GRÁFICO (BOXPLOT E LEGENDA)
  // ==========================================
  Widget _buildAbaGraficos(List<AnalisePotencialGlobalModel> pontos) {
    if (pontos.isEmpty) return const Center(child: Text('Sem dados com este filtro.'));

    // Agrupar Locais Únicos para a Legenda e mapear Cores
    List<String> locaisUnicos = pontos.map((p) => p.local).toSet().toList();
    Map<String, Color> mapaCoresLocal = {};
    for (int i = 0; i < locaisUnicos.length; i++) {
      mapaCoresLocal[locaisUnicos[i]] = _paletaLocais[i % _paletaLocais.length];
    }

    // Criar as Séries do Boxplot (1 série por Local, para que a cor funcione corretamente)
    List<BoxAndWhiskerSeries<BoxPlotDataPotencialAgg, String>> seriesList = [];
    
    // Acha os limites dinâmicos para o eixo X (Visualmente será no topo)
    double minGeral = 0;
    
    for (String local in locaisUnicos) {
      List<BoxPlotDataPotencialAgg> dataSourceLocal = [];
      
      for (var p in pontos.where((p) => p.local == local)) {
        if (p.valoresMv.isNotEmpty) {
          final menorValor = p.valoresMv.reduce(min);
          if (menorValor < minGeral) minGeral = menorValor;
          
          dataSourceLocal.add(
            BoxPlotDataPotencialAgg('${p.nomePonto}\n${p.tipoElemento}', p.local, p.valoresMv)
          );
        }
      }

      if (dataSourceLocal.isNotEmpty) {
        seriesList.add(
          BoxAndWhiskerSeries<BoxPlotDataPotencialAgg, String>(
            dataSource: dataSourceLocal,
            name: local,
            xValueMapper: (d, _) => d.rotuloEixoX,
            yValueMapper: (d, _) => d.valores,
            showMean: true,
            boxPlotMode: BoxPlotMode.normal, // Mostra agrupado no mesmo eixo
            color: mapaCoresLocal[local]!.withValues(alpha: 0.5),
            borderColor: mapaCoresLocal[local]!,
          )
        );
      }
    }
    
    // Arredonda o mínimo para um múltiplo de 100 mais próximo
    double eixoMin = (minGeral / 100).floor() * 100.0;
    if (eixoMin > -400) eixoMin = -400; // Garante que mostre pelo menos até a zona de Alta Corrosão

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legenda Customizada (Locais)
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Local', style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: locaisUnicos.map((local) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: mapaCoresLocal[local]!.withValues(alpha: 0.5),
                          border: Border.all(color: mapaCoresLocal[local]!, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(local, style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF3E3E3D))),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Gráfico BoxPlot
        Container(
          height: max(350, pontos.length * 75.0), // Altura dinâmica baseada na quantidade de elementos
          padding: const EdgeInsets.all( 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: SfCartesianChart(
            title: const ChartTitle(
              text: 'Potencial de corrosão (mV)', 
              textStyle: TextStyle(fontSize: 13, color: Color(0xFF3E3E3D)),
              alignment: ChartAlignment.center
            ),
            margin: EdgeInsets.zero,
            isTransposed: true, // Eixos invertidos (Horizontal)
            plotAreaBorderWidth: 0,
            primaryXAxis: CategoryAxis(
              labelStyle: GoogleFonts.lato(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              majorGridLines: const MajorGridLines(width: 0),
              axisLine: const AxisLine(width: 0),
            ), 
            primaryYAxis: NumericAxis(
              minimum: eixoMin,
              maximum: 0, // Máximo 0 (Padrão ASTM)
              interval: 50,
              labelPosition: ChartDataLabelPosition.outside,
              opposedPosition: true, // Coloca os números em cima
              axisLine: const AxisLine(width: 0),
              majorTickLines: const MajorTickLines(size: 0),
              majorGridLines: const MajorGridLines(width: 1, color: Colors.white),
              plotBands: [
                PlotBand(start: eixoMin, end: -350, color: Colors.red.withValues(alpha: 0.1)),
                PlotBand(start: -350, end: -200, color: Colors.orange.withValues(alpha: 0.15)),
                PlotBand(start: -200, end: 0, color: Colors.green.withValues(alpha: 0.1)),
              ]
            ),
            series: seriesList,
          ),
        ),
      ],
    );
  }
}